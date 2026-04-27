import Foundation
import IOKit.ps

public enum MacOSPowerSource: Equatable, Sendable {
    case battery
    case ac
}

public struct MacOSLockPolicy: Equatable, Sendable {
    public var requiresPassword: Bool
    public var displaySleepDelay: TimeInterval
    public var passwordDelay: TimeInterval

    public init(requiresPassword: Bool, displaySleepDelay: TimeInterval, passwordDelay: TimeInterval) {
        self.requiresPassword = requiresPassword
        self.displaySleepDelay = max(0, displaySleepDelay)
        self.passwordDelay = max(0, passwordDelay)
    }

    public var lockDelay: TimeInterval? {
        guard requiresPassword, displaySleepDelay > 0 else { return nil }
        return displaySleepDelay + passwordDelay
    }
}

public enum MacOSLockPolicyReaderError: Error, LocalizedError, Equatable {
    case powerSettingsUnreadable
    case displaySleepTimerUnavailable

    public var errorDescription: String? {
        switch self {
        case .powerSettingsUnreadable:
            return "Could not read macOS power settings"
        case .displaySleepTimerUnavailable:
            return "Could not read macOS display sleep timer"
        }
    }
}

@MainActor
public protocol MacOSLockPolicyReading: AnyObject {
    func currentPolicy() throws -> MacOSLockPolicy
}

@MainActor
public final class MacOSLockPolicyReader: MacOSLockPolicyReading {
    private static let screenSaverSuiteName = "com.apple.screensaver"
    private static let defaultPowerSettingsPath = "/Library/Preferences/com.apple.PowerManagement.plist"
    private static let batteryPowerKey = "Battery Power"
    private static let acPowerKey = "AC Power"
    private static let upsPowerKey = "UPS Power"
    private static let displaySleepTimerKey = "Display Sleep Timer"
    private static let askForPasswordKey = "askForPassword"
    private static let askForPasswordDelayKey = "askForPasswordDelay"

    private let screenSaverDefaults: UserDefaults
    private let powerSettingsURL: URL
    private let powerSourceProvider: () -> MacOSPowerSource?

    public convenience init() {
        self.init(
            screenSaverDefaults: UserDefaults(suiteName: Self.screenSaverSuiteName) ?? .standard,
            powerSettingsURL: URL(fileURLWithPath: Self.defaultPowerSettingsPath),
            powerSourceProvider: Self.currentPowerSource
        )
    }

    public init(
        screenSaverDefaults: UserDefaults,
        powerSettingsURL: URL,
        powerSourceProvider: @escaping () -> MacOSPowerSource?
    ) {
        self.screenSaverDefaults = screenSaverDefaults
        self.powerSettingsURL = powerSettingsURL
        self.powerSourceProvider = powerSourceProvider
    }

    public func currentPolicy() throws -> MacOSLockPolicy {
        let requiresPassword = Self.boolValue(screenSaverDefaults.object(forKey: Self.askForPasswordKey))
        let passwordDelay = max(0, Self.timeIntervalValue(screenSaverDefaults.object(forKey: Self.askForPasswordDelayKey)) ?? 0)
        let displaySleepDelay = try currentDisplaySleepDelay()

        return MacOSLockPolicy(
            requiresPassword: requiresPassword,
            displaySleepDelay: displaySleepDelay,
            passwordDelay: passwordDelay
        )
    }

    private func currentDisplaySleepDelay() throws -> TimeInterval {
        let settings = try readPowerSettings()
        let source = powerSourceProvider()
        let timerMinutes = try displaySleepTimerMinutes(in: settings, preferredSource: source)
        return max(0, timerMinutes) * 60
    }

    private func readPowerSettings() throws -> [String: Any] {
        do {
            let data = try Data(contentsOf: powerSettingsURL)
            guard let dictionary = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any] else {
                throw MacOSLockPolicyReaderError.powerSettingsUnreadable
            }
            return dictionary
        } catch let error as MacOSLockPolicyReaderError {
            throw error
        } catch {
            throw MacOSLockPolicyReaderError.powerSettingsUnreadable
        }
    }

    private func displaySleepTimerMinutes(in settings: [String: Any], preferredSource: MacOSPowerSource?) throws -> TimeInterval {
        let preferredKeys: [String]
        switch preferredSource {
        case .battery:
            preferredKeys = [Self.batteryPowerKey, Self.acPowerKey]
        case .ac:
            preferredKeys = [Self.acPowerKey, Self.batteryPowerKey]
        case nil:
            preferredKeys = [Self.batteryPowerKey, Self.acPowerKey]
        }

        for sourceKey in preferredKeys {
            guard let sourceSettings = settings[sourceKey] as? [String: Any] else { continue }
            if let minutes = Self.timeIntervalValue(sourceSettings[Self.displaySleepTimerKey]) {
                return minutes
            }
        }

        throw MacOSLockPolicyReaderError.displaySleepTimerUnavailable
    }

    private static func currentPowerSource() -> MacOSPowerSource? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let unmanagedSource = IOPSGetProvidingPowerSourceType(snapshot) else {
            return nil
        }
        let rawSource = unmanagedSource.takeUnretainedValue() as String

        switch rawSource {
        case batteryPowerKey:
            return .battery
        case acPowerKey, upsPowerKey:
            return .ac
        default:
            return nil
        }
    }

    private static func boolValue(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.intValue != 0 }
        if let string = value as? String {
            return string == "1" || string.lowercased() == "true" || string.lowercased() == "yes"
        }
        return false
    }

    private static func timeIntervalValue(_ value: Any?) -> TimeInterval? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let timeInterval = value as? TimeInterval { return timeInterval }
        if let int = value as? Int { return TimeInterval(int) }
        if let double = value as? Double { return double }
        if let string = value as? String { return TimeInterval(string) }
        return nil
    }
}
