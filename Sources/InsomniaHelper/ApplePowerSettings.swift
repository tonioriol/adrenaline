import CoreFoundation
import Foundation
import IOKit

private let sleepDisabledKey = "SleepDisabled" as CFString

@_silgen_name("IOPMSetSystemPowerSetting")
private func IOPMSetSystemPowerSetting(_ key: CFString, _ value: CFTypeRef) -> IOReturn

@_silgen_name("IOPMCopySystemPowerSettings")
private func IOPMCopySystemPowerSettings() -> Unmanaged<CFDictionary>?

enum ApplePowerSettingsError: Error, LocalizedError {
    case setFailed(IOReturn)
    case readFailed

    var errorDescription: String? {
        switch self {
        case let .setFailed(code):
            return "Failed to update SleepDisabled: IOReturn \(code)"
        case .readFailed:
            return "Failed to read SleepDisabled"
        }
    }
}

final class ApplePowerSettings {
    func setLidClosePreventionEnabled(_ enabled: Bool) throws {
        let value: CFBoolean = enabled ? kCFBooleanTrue : kCFBooleanFalse
        let result = IOPMSetSystemPowerSetting(sleepDisabledKey, value)
        guard result == kIOReturnSuccess else {
            throw ApplePowerSettingsError.setFailed(result)
        }
    }

    func isLidClosePreventionEnabled() throws -> Bool {
        guard let unmanaged = IOPMCopySystemPowerSettings() else {
            throw ApplePowerSettingsError.readFailed
        }

        let dictionary = unmanaged.takeRetainedValue() as NSDictionary
        return (dictionary[sleepDisabledKey as String] as? Bool) ?? false
    }
}
