import Foundation

public struct MacOSLockPolicy: Equatable, Sendable {
    public var requiresPassword: Bool

    public init(requiresPassword: Bool) {
        self.requiresPassword = requiresPassword
    }
}

@MainActor
public protocol MacOSLockPolicyReading: AnyObject {
    func currentPolicy() throws -> MacOSLockPolicy
}

@MainActor
public final class MacOSLockPolicyReader: MacOSLockPolicyReading {
    private static let screenSaverSuiteName = "com.apple.screensaver"
    private static let askForPasswordKey = "askForPassword"

    private let screenSaverDefaults: UserDefaults

    public convenience init() {
        self.init(screenSaverDefaults: UserDefaults(suiteName: Self.screenSaverSuiteName) ?? .standard)
    }

    public init(screenSaverDefaults: UserDefaults) {
        self.screenSaverDefaults = screenSaverDefaults
    }

    public func currentPolicy() throws -> MacOSLockPolicy {
        MacOSLockPolicy(
            requiresPassword: Self.boolValue(screenSaverDefaults.object(forKey: Self.askForPasswordKey))
        )
    }

    private static func boolValue(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.intValue != 0 }
        if let string = value as? String {
            return string == "1" || string.lowercased() == "true" || string.lowercased() == "yes"
        }
        return false
    }
}
