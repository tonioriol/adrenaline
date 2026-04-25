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
    private static let log = OSLog(subsystem: "com.tr0n.Cocaine", category: "ScreenLocker")
    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/login.framework/Versions/A/login"

    private let lockSymbol: (@convention(c) () -> Int32)?

    public init() {
        self.lockSymbol = LoginFrameworkScreenLocker.loadLockSymbol()
    }

    public func lock() throws {
        if let lockSymbol {
            _ = lockSymbol()
            return
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
            return nil
        }

        return unsafeBitCast(symbol, to: (@convention(c) () -> Int32).self)
    }

    private static func invokeLoginwindowFallback() throws {
        // CGSession -suspend is the documented public command-line lock-session
        // technique on macOS and is preferred over AppleScript automation
        // (which would require an Automation permission grant).
        let process = Process()
        process.launchPath = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        process.arguments = ["-suspend"]

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                throw ScreenLockerError.fallbackFailed(process.terminationStatus)
            }
        } catch let error as ScreenLockerError {
            throw error
        } catch {
            throw ScreenLockerError.symbolUnavailable
        }
    }
}
