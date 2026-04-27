import Foundation
import IOKit.pwr_mgt

public protocol PowerAssertionClient: AnyObject {
    func createNoIdleSleepAssertion(reason: String) throws -> UInt32
    func createDisplaySleepAssertion(reason: String) throws -> UInt32
    func releaseAssertion(id: UInt32)
}

public enum PowerAssertionError: Error, LocalizedError, Equatable {
    case creationFailed(type: String, code: IOReturn)

    public var errorDescription: String? {
        switch self {
        case let .creationFailed(type, code):
            return "Failed to create \(type) assertion: IOReturn \(code)"
        }
    }
}

public final class IOKitPowerAssertionClient: PowerAssertionClient {
    public init() {}

    public func createNoIdleSleepAssertion(reason: String) throws -> UInt32 {
        try createAssertion(type: kIOPMAssertionTypeNoIdleSleep as CFString, typeName: "no-idle-sleep", reason: reason)
    }

    public func createDisplaySleepAssertion(reason: String) throws -> UInt32 {
        try createAssertion(type: kIOPMAssertPreventUserIdleDisplaySleep as CFString, typeName: "display-sleep", reason: reason)
    }

    public func releaseAssertion(id: UInt32) {
        IOPMAssertionRelease(IOPMAssertionID(id))
    }

    private func createAssertion(type: CFString, typeName: String, reason: String) throws -> UInt32 {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(type, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &assertionID)
        guard result == kIOReturnSuccess else {
            throw PowerAssertionError.creationFailed(type: typeName, code: result)
        }
        return UInt32(assertionID)
    }
}
