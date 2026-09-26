import Darwin
import Foundation

/// Wire protocol: newline-delimited JSON over a Unix domain socket.
///
/// Requests (one JSON object per line):
///   {"cmd":"hold","reason":"optional text","pid":123}  keep Adrenaline on while this connection is open
///   {"cmd":"release"}                                   drop this connection's hold
///   {"cmd":"status"}                                    report state and current holds
/// Every request gets exactly one JSON line back, always with an "ok" field.
/// A hold is tied to its connection: closing the socket (or the process dying) releases it.
public enum HoldSocket {
    public static var defaultPath: String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Adrenaline/adrenaline.sock").path
    }

    static func address(for path: String) throws -> sockaddr_un {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else {
            throw HoldSocketError.pathTooLong(path)
        }
        withUnsafeMutableBytes(of: &addr.sun_path) { $0.copyBytes(from: bytes) }
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        return addr
    }
}

public enum HoldSocketError: Error, LocalizedError, Equatable {
    case pathTooLong(String)
    case system(String, Int32)

    public var errorDescription: String? {
        switch self {
        case .pathTooLong(let path): return "Socket path is too long: \(path)"
        case .system(let call, let code): return "\(call) failed: \(String(cString: strerror(code)))"
        }
    }
}

// MARK: - Server

/// Serves the hold protocol on the main queue.
public final class HoldSocketServer {
    private final class Connection {
        let fd: Int32
        let source: DispatchSourceRead
        let peerPID: Int32?
        var buffer = Data()
        var holdID: Int?

        init(fd: Int32, source: DispatchSourceRead, peerPID: Int32?) {
            self.fd = fd
            self.source = source
            self.peerPID = peerPID
        }
    }

    private static let maxLineLength = 64 * 1024

    public let path: String
    private let holds: HoldController
    private let state: AppState
    private var listenFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var connections: [Int32: Connection] = [:]

    public init(path: String = HoldSocket.defaultPath, holds: HoldController, state: AppState) {
        self.path = path
        self.holds = holds
        self.state = state
    }

    deinit { stop() }

    public func start() throws {
        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        var addr = try HoldSocket.address(for: path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw HoldSocketError.system("socket", errno) }
        unlink(path)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0, chmod(path, 0o600) == 0, listen(fd, 16) == 0 else {
            let code = errno
            close(fd)
            throw HoldSocketError.system("bind/listen", code)
        }
        setNonBlocking(fd)

        listenFD = fd
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in self?.acceptPending() }
        source.resume()
        acceptSource = source
    }

    public func stop() {
        for connection in Array(connections.values) { drop(connection) }
        acceptSource?.cancel()
        acceptSource = nil
        if listenFD >= 0 {
            close(listenFD)
            listenFD = -1
            unlink(path)
        }
    }

    private func acceptPending() {
        while true {
            let fd = accept(listenFD, nil, nil)
            guard fd >= 0 else { return }
            setNonBlocking(fd)
            var noSigPipe: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
            let connection = Connection(fd: fd, source: source, peerPID: peerPID(of: fd))
            source.setEventHandler { [weak self, weak connection] in
                guard let self, let connection else { return }
                self.readAvailable(connection)
            }
            connections[fd] = connection
            source.resume()
        }
    }

    private func readAvailable(_ connection: Connection) {
        var chunk = [UInt8](repeating: 0, count: 4096)
        let count = read(connection.fd, &chunk, chunk.count)
        if count < 0, errno == EAGAIN || errno == EINTR { return }
        guard count > 0 else {
            drop(connection)
            return
        }
        connection.buffer.append(contentsOf: chunk[0..<count])

        while let newline = connection.buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = connection.buffer[connection.buffer.startIndex..<newline]
            connection.buffer.removeSubrange(connection.buffer.startIndex...newline)
            send(handle(line: Data(line), on: connection), to: connection)
        }
        if connection.buffer.count > Self.maxLineLength {
            drop(connection)
        }
    }

    private func handle(line: Data, on connection: Connection) -> [String: Any] {
        guard let request = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
              let command = request["cmd"] as? String else {
            return ["ok": false, "error": "expected a JSON object with a \"cmd\" field"]
        }

        switch command {
        case "hold":
            if let id = connection.holdID { holds.release(id) }
            let pid = (request["pid"] as? NSNumber)?.int32Value ?? connection.peerPID
            let id = holds.acquire(reason: request["reason"] as? String, pid: pid)
            connection.holdID = id
            return ["ok": true, "id": id]
        case "release":
            if let id = connection.holdID { holds.release(id) }
            connection.holdID = nil
            return ["ok": true]
        case "status":
            return status()
        default:
            return ["ok": false, "error": "unknown cmd \"\(command)\""]
        }
    }

    private func status() -> [String: Any] {
        var response: [String: Any] = [
            "ok": true,
            "active": state.isActive,
            "busy": state.isBusy,
            "holdDriven": holds.isHoldDriven,
            "holds": holds.holds.map { hold -> [String: Any] in
                var entry: [String: Any] = ["id": hold.id]
                if let reason = hold.reason { entry["reason"] = reason }
                if let pid = hold.pid { entry["pid"] = Int(pid) }
                return entry
            },
        ]
        if let error = state.lastErrorMessage { response["error"] = error }
        return response
    }

    private func send(_ response: [String: Any], to connection: Connection) {
        guard var data = try? JSONSerialization.data(withJSONObject: response, options: [.sortedKeys]) else { return }
        data.append(UInt8(ascii: "\n"))
        data.withUnsafeBytes { raw in
            _ = write(connection.fd, raw.baseAddress, raw.count)
        }
    }

    private func drop(_ connection: Connection) {
        guard connections.removeValue(forKey: connection.fd) != nil else { return }
        connection.source.cancel()
        close(connection.fd)
        if let id = connection.holdID { holds.release(id) }
    }

    private func setNonBlocking(_ fd: Int32) {
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
    }

    private func peerPID(of fd: Int32) -> Int32? {
        var pid: pid_t = 0
        var length = socklen_t(MemoryLayout<pid_t>.size)
        return getsockopt(fd, SOL_LOCAL, LOCAL_PEERPID, &pid, &length) == 0 ? pid : nil
    }
}

// MARK: - Client

/// Minimal blocking client, used by the `adrenaline` command-line tool and tests.
public final class HoldSocketClient {
    public let fd: Int32
    private var buffer = Data()

    public init(path: String = HoldSocket.defaultPath) throws {
        var addr = try HoldSocket.address(for: path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw HoldSocketError.system("socket", errno) }
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            let code = errno
            close(fd)
            throw HoldSocketError.system("connect", code)
        }
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        self.fd = fd
    }

    deinit { close(fd) }

    /// Sends one request and blocks until its response line arrives.
    public func request(_ body: [String: Any]) throws -> [String: Any] {
        var data = try JSONSerialization.data(withJSONObject: body)
        data.append(UInt8(ascii: "\n"))
        let written = data.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
        guard written == data.count else { throw HoldSocketError.system("write", errno) }

        while true {
            if let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[buffer.startIndex..<newline]
                buffer.removeSubrange(buffer.startIndex...newline)
                return (try JSONSerialization.jsonObject(with: Data(line)) as? [String: Any]) ?? [:]
            }
            var chunk = [UInt8](repeating: 0, count: 4096)
            let count = read(fd, &chunk, chunk.count)
            guard count > 0 else { throw HoldSocketError.system("read", count == 0 ? ECONNRESET : errno) }
            buffer.append(contentsOf: chunk[0..<count])
        }
    }
}
