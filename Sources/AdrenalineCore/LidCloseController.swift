import Foundation

public final class LidCloseController: LidCloseControlling {
    private let helperClient: PrivilegedHelperClientProtocol

    public init(helperClient: PrivilegedHelperClientProtocol = PrivilegedHelperClient()) {
        self.helperClient = helperClient
    }

    public func enable(completion: @escaping (Error?) -> Void) {
        helperClient.installOrUpdateHelperIfNeeded { [weak self] error in
            if let error {
                completion(error)
                return
            }
            self?.helperClient.enableLidClosePrevention(completion: completion)
        }
    }

    public func disable(completion: @escaping (Error?) -> Void) {
        helperClient.disableLidClosePrevention(completion: completion)
    }

    public func status(completion: @escaping (Result<Bool, Error>) -> Void) {
        helperClient.readLidClosePreventionStatus(completion: completion)
    }
}
