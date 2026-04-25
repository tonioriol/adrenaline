import Foundation

public final class AwakeController: AwakeControlling {
    private let client: PowerAssertionClient
    private var systemAssertionID: UInt32?
    private var displayAssertionID: UInt32?

    public var isEnabled: Bool { systemAssertionID != nil }

    public init(client: PowerAssertionClient = IOKitPowerAssertionClient()) {
        self.client = client
    }

    public func enable() throws {
        try enable(preventDisplaySleep: true)
    }

    public func enable(preventDisplaySleep: Bool) throws {
        guard !isEnabled else { return }

        var rolledBackIDs: [UInt32] = []
        do {
            let systemID = try client.createNoIdleSleepAssertion(reason: "Cocaine is active")
            rolledBackIDs.append(systemID)
            systemAssertionID = systemID

            if preventDisplaySleep {
                let displayID = try client.createDisplaySleepAssertion(reason: "Cocaine is active")
                rolledBackIDs.append(displayID)
                displayAssertionID = displayID
            }
        } catch {
            for id in rolledBackIDs {
                client.releaseAssertion(id: id)
            }
            systemAssertionID = nil
            displayAssertionID = nil
            throw error
        }
    }

    public func setPreventDisplaySleep(_ enabled: Bool) throws {
        guard isEnabled else { return }

        if enabled {
            guard displayAssertionID == nil else { return }
            let displayID = try client.createDisplaySleepAssertion(reason: "Cocaine is active")
            displayAssertionID = displayID
        } else {
            guard let id = displayAssertionID else { return }
            client.releaseAssertion(id: id)
            displayAssertionID = nil
        }
    }

    public func disable() {
        if let id = displayAssertionID {
            client.releaseAssertion(id: id)
            displayAssertionID = nil
        }
        if let id = systemAssertionID {
            client.releaseAssertion(id: id)
            systemAssertionID = nil
        }
    }
}
