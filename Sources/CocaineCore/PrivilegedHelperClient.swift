import Foundation

public enum PrivilegedHelperClientError: Error, LocalizedError, Equatable {
    case notImplemented
    case helperReturnedError(String)
    case invalidReply
    case authorizationFailed(OSStatus)
    case blessFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Privileged helper client is not implemented"
        case let .helperReturnedError(message):
            return message
        case .invalidReply:
            return "Privileged helper returned an invalid reply"
        case let .authorizationFailed(status):
            return "Authorization failed with status \(status)"
        case let .blessFailed(message):
            return "Helper installation failed: \(message)"
        }
    }
}

public final class PrivilegedHelperClient: PrivilegedHelperClientProtocol {
    public init() {}

    public func installOrUpdateHelperIfNeeded() async throws {
        throw PrivilegedHelperClientError.notImplemented
    }

    public func enableLidClosePrevention() async throws {
        throw PrivilegedHelperClientError.notImplemented
    }

    public func disableLidClosePrevention() async throws {
        throw PrivilegedHelperClientError.notImplemented
    }

    public func readLidClosePreventionStatus() async throws -> Bool {
        throw PrivilegedHelperClientError.notImplemented
    }
}
