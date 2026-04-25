import Foundation

public final class AwakeController: AwakeControlling {
    private let client: PowerAssertionClient
    private var assertionIDs: [UInt32]

    public private(set) var isEnabled: Bool

    public init(client: PowerAssertionClient = IOKitPowerAssertionClient()) {
        self.client = client
        self.assertionIDs = []
        self.isEnabled = false
    }

    public func enable() throws {
        guard !isEnabled else { return }

        do {
            let systemID = try client.createNoIdleSleepAssertion(reason: "Cocaine is active")
            let displayID = try client.createDisplaySleepAssertion(reason: "Cocaine is active")
            assertionIDs = [systemID, displayID]
            isEnabled = true
        } catch {
            releaseAllAssertions()
            throw error
        }
    }

    public func disable() {
        releaseAllAssertions()
        isEnabled = false
    }

    private func releaseAllAssertions() {
        for id in assertionIDs {
            client.releaseAssertion(id: id)
        }
        assertionIDs.removeAll()
    }
}
