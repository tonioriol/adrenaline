import Foundation

public final class LidCloseController: LidCloseControlling {
    private let helperClient: PrivilegedHelperClientProtocol

    public init(helperClient: PrivilegedHelperClientProtocol = PrivilegedHelperClient()) {
        self.helperClient = helperClient
    }

    public func enable() async throws {
        try await helperClient.installOrUpdateHelperIfNeeded()
        try await helperClient.enableLidClosePrevention()
    }

    public func disable() async throws {
        try await helperClient.disableLidClosePrevention()
    }

    public func status() async throws -> Bool {
        try await helperClient.readLidClosePreventionStatus()
    }
}
