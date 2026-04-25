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

        var createdIDs: [UInt32] = []
        do {
            let systemID = try client.createNoIdleSleepAssertion(reason: "Cocaine is active")
            createdIDs.append(systemID)
            let displayID = try client.createDisplaySleepAssertion(reason: "Cocaine is active")
            createdIDs.append(displayID)
            assertionIDs = createdIDs
            isEnabled = true
        } catch {
            for id in createdIDs {
                client.releaseAssertion(id: id)
            }
            assertionIDs.removeAll()
            isEnabled = false
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
