import Foundation
import Security

/// The macOS "Require password after screen saver begins or display is turned off" setting.
public enum ScreenLockDelay: Equatable {
    case off
    case immediate
    case seconds(Int)

    var argument: String {
        switch self {
        case .off: return "off"
        case .immediate: return "immediate"
        case let .seconds(value): return String(value)
        }
    }

    init?(argument: String) {
        switch argument {
        case "off": self = .off
        case "immediate": self = .immediate
        default:
            guard let value = Int(argument) else { return nil }
            self = .seconds(value)
        }
    }

    /// Parses `sysadminctl -screenLock status` output, e.g. "screenLock delay is immediate",
    /// "screenLock is off" or "screenLock delay is 300 seconds".
    static func parse(statusOutput output: String) -> ScreenLockDelay? {
        if output.contains("screenLock is off") { return .off }
        guard let range = output.range(of: "screenLock delay is ") else { return nil }
        let rest = output[range.upperBound...]
        if rest.hasPrefix("immediate") { return .immediate }
        let digits = rest.prefix { $0.isNumber }
        guard let value = Int(digits) else { return nil }
        return .seconds(value)
    }
}

public enum ScreenLockSettingError: Error, LocalizedError, Equatable {
    case statusUnreadable(String)
    case changeRejected(String)
    case passwordMissing

    public var errorDescription: String? {
        switch self {
        case let .statusUnreadable(output):
            return "Could not read the macOS lock setting: \(output)"
        case let .changeRejected(output):
            return "macOS refused to change the lock setting (wrong login password?): \(output)"
        case .passwordMissing:
            return "Stay unlocked needs your login password again"
        }
    }
}

public protocol ScreenLockSettingControlling: AnyObject {
    func currentDelay() throws -> ScreenLockDelay
    func setDelay(_ delay: ScreenLockDelay, password: String) throws
}

/// Reads and changes the lock setting through `sysadminctl`, which requires the user's
/// login password even when run as root.
public final class SysadminctlScreenLockSetting: ScreenLockSettingControlling {
    private static let executablePath = "/usr/sbin/sysadminctl"

    public init() {}

    public func currentDelay() throws -> ScreenLockDelay {
        let result = try Self.run(["-screenLock", "status"], stdin: nil)
        guard let delay = ScreenLockDelay.parse(statusOutput: result.output) else {
            throw ScreenLockSettingError.statusUnreadable(result.output)
        }
        return delay
    }

    public func setDelay(_ delay: ScreenLockDelay, password: String) throws {
        let result = try Self.run(["-screenLock", delay.argument, "-password", "-"], stdin: password + "\n")
        let rejected = result.status != 0
            || result.output.localizedCaseInsensitiveContains("error")
            || result.output.localizedCaseInsensitiveContains("password is required")
        guard !rejected else { throw ScreenLockSettingError.changeRejected(result.output) }
        if try currentDelay() != delay {
            throw ScreenLockSettingError.changeRejected(result.output)
        }
    }

    private static func run(_ arguments: [String], stdin: String?) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        let inputPipe = Pipe()
        process.standardInput = inputPipe

        try process.run()
        if let stdin {
            inputPipe.fileHandleForWriting.write(Data(stdin.utf8))
        }
        inputPipe.fileHandleForWriting.closeFile()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return (process.terminationStatus, output)
    }
}

public protocol PasswordStoring: AnyObject {
    func read() -> String?
    func save(_ password: String) throws
}

public enum KeychainPasswordStoreError: Error, LocalizedError {
    case saveFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case let .saveFailed(status):
            return "Could not save the password to the Keychain (OSStatus \(status))"
        }
    }
}

public final class KeychainPasswordStore: PasswordStoring {
    private let service: String
    private let account: String

    public init(service: String = "com.tonioriol.adrenaline.login-password", account: String = NSUserName()) {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func save(_ password: String) throws {
        SecItemDelete(baseQuery as CFDictionary)
        var query = baseQuery
        query[kSecValueData as String] = Data(password.utf8)
        query[kSecAttrLabel as String] = "Adrenaline (Stay unlocked when lid is closed)"
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainPasswordStoreError.saveFailed(status)
        }
    }
}
