import Foundation
import Security
import ServiceManagement

public enum PrivilegedHelperClientError: Error, LocalizedError, Equatable {
    case helperReturnedError(String)
    case invalidReply
    case authorizationFailed(OSStatus)
    case blessFailed(String)
    case xpcConnectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .helperReturnedError(message):
            return message
        case .invalidReply:
            return "Privileged helper returned an invalid reply"
        case let .authorizationFailed(status):
            return "Authorization failed with status \(status)"
        case let .blessFailed(message):
            return "Helper installation failed: \(message)"
        case let .xpcConnectionFailed(message):
            return "Helper connection failed: \(message)"
        }
    }
}

public final class PrivilegedHelperClient: PrivilegedHelperClientProtocol {
    private let helperIdentifier: String

    public init(helperIdentifier: String = CocaineHelperConstants.helperBundleIdentifier) {
        self.helperIdentifier = helperIdentifier
    }

    public func installOrUpdateHelperIfNeeded() async throws {
        if let version = try? await helperVersion(), version == CocaineHelperConstants.helperVersion {
            return
        }
        try blessHelper()
    }

    public func enableLidClosePrevention() async throws {
        _ = try await callBooleanCommand { helper, reply in
            helper.enableLidClosePrevention(reply: reply)
        }
    }

    public func disableLidClosePrevention() async throws {
        _ = try await callBooleanCommand { helper, reply in
            helper.disableLidClosePrevention(reply: reply)
        }
    }

    public func readLidClosePreventionStatus() async throws -> Bool {
        try await callBooleanCommand { helper, reply in
            helper.readLidClosePreventionStatus(reply: reply)
        }
    }

    private func helperVersion() async throws -> Int {
        let helper = try makeRemoteHelperProxy()
        return try await withCheckedThrowingContinuation { continuation in
            helper.helperVersion { version in
                continuation.resume(returning: version.intValue)
            }
        }
    }

    private func callBooleanCommand(
        _ command: @escaping (CocaineHelperProtocol, @escaping (NSNumber, NSString?) -> Void) -> Void
    ) async throws -> Bool {
        let helper = try makeRemoteHelperProxy()
        return try await withCheckedThrowingContinuation { continuation in
            command(helper) { value, errorMessage in
                if let errorMessage {
                    continuation.resume(throwing: PrivilegedHelperClientError.helperReturnedError(errorMessage as String))
                } else {
                    continuation.resume(returning: value.boolValue)
                }
            }
        }
    }

    private func makeRemoteHelperProxy() throws -> CocaineHelperProtocol {
        let connection = NSXPCConnection(machServiceName: helperIdentifier, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: CocaineHelperProtocol.self)
        connection.resume()

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            NSLog("Cocaine helper XPC error: \(error.localizedDescription)")
        }) as? CocaineHelperProtocol else {
            connection.invalidate()
            throw PrivilegedHelperClientError.xpcConnectionFailed("Could not create remote proxy")
        }

        return proxy
    }

    private func blessHelper() throws {
        var authRef: AuthorizationRef?
        let flags: AuthorizationFlags = [.interactionAllowed, .preAuthorize, .extendRights]

        let authStatus = kSMRightBlessPrivilegedHelper.withCString { rightName in
            var authItem = AuthorizationItem(name: rightName, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &authItem) { authItemPointer in
                var authRights = AuthorizationRights(count: 1, items: authItemPointer)
                return AuthorizationCreate(&authRights, nil, flags, &authRef)
            }
        }
        guard authStatus == errAuthorizationSuccess, let authRef else {
            throw PrivilegedHelperClientError.authorizationFailed(authStatus)
        }

        var unmanagedError: Unmanaged<CFError>?
        let blessed = SMJobBless(kSMDomainSystemLaunchd, helperIdentifier as CFString, authRef, &unmanagedError)
        guard blessed else {
            let message = unmanagedError?.takeRetainedValue().localizedDescription ?? "SMJobBless returned false"
            throw PrivilegedHelperClientError.blessFailed(message)
        }
    }
}
