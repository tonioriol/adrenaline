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

    public init(helperIdentifier: String = AdrenalineHelperConstants.helperBundleIdentifier) {
        self.helperIdentifier = helperIdentifier
    }

    public func installOrUpdateHelperIfNeeded(completion: @escaping (Error?) -> Void) {
        helperVersion { [weak self] result in
            switch result {
            case .success(let version) where version == AdrenalineHelperConstants.helperVersion:
                DispatchQueue.main.async { completion(nil) }
            default:
                guard let self else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                do {
                    try self.blessHelper()
                    DispatchQueue.main.async { completion(nil) }
                } catch {
                    DispatchQueue.main.async { completion(error) }
                }
            }
        }
    }

    public func enableLidClosePrevention(completion: @escaping (Error?) -> Void) {
        callBooleanCommand(
            { helper, reply in helper.enableLidClosePrevention(reply: reply) },
            requiresSuccess: true
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success: completion(nil)
                case .failure(let error): completion(error)
                }
            }
        }
    }

    public func disableLidClosePrevention(completion: @escaping (Error?) -> Void) {
        callBooleanCommand(
            { helper, reply in helper.disableLidClosePrevention(reply: reply) },
            requiresSuccess: true
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success: completion(nil)
                case .failure(let error): completion(error)
                }
            }
        }
    }

    public func readLidClosePreventionStatus(completion: @escaping (Result<Bool, Error>) -> Void) {
        callBooleanCommand(
            { helper, reply in helper.readLidClosePreventionStatus(reply: reply) },
            requiresSuccess: false
        ) { result in
            DispatchQueue.main.async { completion(result) }
        }
    }

    private func helperVersion(completion: @escaping (Result<Int, Error>) -> Void) {
        withHelperConnection { helper, complete in
            helper.helperVersion { version in
                complete(.success(version.intValue))
            }
        } completion: { result in
            completion(result)
        }
    }

    private func callBooleanCommand(
        _ command: @escaping (AdrenalineHelperProtocol, @escaping (NSNumber, NSString?) -> Void) -> Void,
        requiresSuccess: Bool,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        withHelperConnection { helper, complete in
            command(helper) { value, errorMessage in
                complete(Result {
                    try Self.decodeBooleanReply(value, errorMessage: errorMessage, requiresSuccess: requiresSuccess)
                })
            }
        } completion: { result in
            completion(result)
        }
    }

    private func withHelperConnection<T>(
        _ body: @escaping (AdrenalineHelperProtocol, @escaping (Result<T, Error>) -> Void) -> Void,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let connection = NSXPCConnection(machServiceName: helperIdentifier, options: .privileged)
        let lock = NSLock()
        var didComplete = false

        let complete: (Result<T, Error>) -> Void = { result in
            lock.lock()
            guard !didComplete else {
                lock.unlock()
                return
            }
            didComplete = true
            lock.unlock()

            connection.invalidate()
            completion(result)
        }

        connection.remoteObjectInterface = NSXPCInterface(with: AdrenalineHelperProtocol.self)
        connection.interruptionHandler = {
            complete(.failure(PrivilegedHelperClientError.xpcConnectionFailed("Helper connection interrupted")))
        }
        connection.invalidationHandler = {
            complete(.failure(PrivilegedHelperClientError.xpcConnectionFailed("Helper connection invalidated")))
        }
        connection.resume()

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            complete(.failure(PrivilegedHelperClientError.xpcConnectionFailed(error.localizedDescription)))
        }) as? AdrenalineHelperProtocol else {
            complete(.failure(PrivilegedHelperClientError.xpcConnectionFailed("Could not create remote proxy")))
            return
        }

        body(proxy, complete)
    }

    internal static func decodeBooleanReply(
        _ value: NSNumber,
        errorMessage: NSString?,
        requiresSuccess: Bool
    ) throws -> Bool {
        if let errorMessage {
            throw PrivilegedHelperClientError.helperReturnedError(errorMessage as String)
        }

        let boolValue = value.boolValue
        if requiresSuccess, !boolValue {
            throw PrivilegedHelperClientError.invalidReply
        }

        return boolValue
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
        defer { AuthorizationFree(authRef, []) }

        var unmanagedError: Unmanaged<CFError>?
        let blessed = SMJobBless(kSMDomainSystemLaunchd, helperIdentifier as CFString, authRef, &unmanagedError)
        guard blessed else {
            let message = unmanagedError?.takeRetainedValue().localizedDescription ?? "SMJobBless returned false"
            throw PrivilegedHelperClientError.blessFailed(message)
        }
    }
}
