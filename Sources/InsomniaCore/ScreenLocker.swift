import Foundation
import os.log

@MainActor
public protocol ScreenLocking: AnyObject {
    func lock() throws
}

public enum ScreenLockerError: Error, LocalizedError {
    case symbolUnavailable
    case fallbackFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case .symbolUnavailable:
            return "SACLockScreenImmediate is not available on this system"
        case let .fallbackFailed(code):
            return "loginwindow lock fallback failed with status \(code)"
        }
    }
}

@MainActor
public final class LoginFrameworkScreenLocker: ScreenLocking {
    private static let log = OSLog(subsystem: "com.tonioriol.insomnia", category: "ScreenLocker")
    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/login.framework/Versions/A/login"

    private struct FallbackCommand {
        let executablePath: String
        let arguments: [String]
    }

    private static let fallbackCommands = [
        FallbackCommand(
            executablePath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession",
            arguments: ["-suspend"]
        ),
        FallbackCommand(
            executablePath: "/usr/bin/osascript",
            arguments: ["-e", "tell application \"loginwindow\" to «event aevtrlck»"]
        ),
    ]

    private let lockSymbol: (@convention(c) () -> Int32)?

    public init() {
        self.lockSymbol = LoginFrameworkScreenLocker.loadLockSymbol()
    }

    public func lock() throws {
        if let lockSymbol {
            let status = lockSymbol()
            if status == 0 {
                return
            }
        }

        try Self.invokeLoginwindowFallback()
    }

    private static func loadLockSymbol() -> (@convention(c) () -> Int32)? {
        guard let handle = dlopen(frameworkPath, RTLD_LAZY) else {
            let message: String
            if let raw = dlerror() {
                message = String(cString: raw)
            } else {
                message = "unknown"
            }
            os_log("login framework not loadable: %{public}s",
                   log: log,
                   type: .info,
                   message)
            return nil
        }

        guard let symbol = dlsym(handle, "SACLockScreenImmediate") else {
            os_log("SACLockScreenImmediate symbol unavailable",
                   log: log,
                   type: .info)
            dlclose(handle)
            return nil
        }

        return unsafeBitCast(symbol, to: (@convention(c) () -> Int32).self)
    }

    private static func invokeLoginwindowFallback() throws {
        var attemptedFallback = false
        var lastStatus: Int32?

        for command in fallbackCommands {
            guard FileManager.default.isExecutableFile(atPath: command.executablePath) else { continue }
            attemptedFallback = true

            let process = Process()
            process.executableURL = URL(fileURLWithPath: command.executablePath)
            process.arguments = command.arguments

            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    return
                }
                lastStatus = process.terminationStatus
            } catch {
                lastStatus = -1
            }
        }

        if attemptedFallback, let lastStatus {
            throw ScreenLockerError.fallbackFailed(lastStatus)
        }

        throw ScreenLockerError.symbolUnavailable
    }
}
