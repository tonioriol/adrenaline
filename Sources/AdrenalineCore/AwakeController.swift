import Foundation

public final class AwakeController: AwakeControlling {
    private let client: PowerAssertionClient
    private var systemAssertionID: UInt32?
    private var displayAssertionID: UInt32?
    private var diskAssertionID: UInt32?

    public var isEnabled: Bool { systemAssertionID != nil }

    public init(client: PowerAssertionClient = IOKitPowerAssertionClient()) {
        self.client = client
    }

    public func enable() throws {
        try enable(preventDisplaySleep: true, preventDiskSleep: false)
    }

    public func enable(preventDisplaySleep: Bool) throws {
        try enable(preventDisplaySleep: preventDisplaySleep, preventDiskSleep: false)
    }

    public func enable(preventDisplaySleep: Bool, preventDiskSleep: Bool) throws {
        guard !isEnabled else { return }

        var rolledBackIDs: [UInt32] = []
        do {
            let systemID = try client.createNoIdleSleepAssertion(reason: "Adrenaline is active")
            rolledBackIDs.append(systemID)
            systemAssertionID = systemID

            if preventDisplaySleep {
                let displayID = try client.createDisplaySleepAssertion(reason: "Adrenaline is active")
                rolledBackIDs.append(displayID)
                displayAssertionID = displayID
            }

            if preventDiskSleep {
                let diskID = try client.createDiskSleepAssertion(reason: "Adrenaline is active")
                rolledBackIDs.append(diskID)
                diskAssertionID = diskID
            }
        } catch {
            for id in rolledBackIDs {
                client.releaseAssertion(id: id)
            }
            systemAssertionID = nil
            displayAssertionID = nil
            diskAssertionID = nil
            throw error
        }
    }

    public func setPreventDisplaySleep(_ enabled: Bool) throws {
        guard isEnabled else { return }

        if enabled {
            guard displayAssertionID == nil else { return }
            let displayID = try client.createDisplaySleepAssertion(reason: "Adrenaline is active")
            displayAssertionID = displayID
        } else {
            guard let id = displayAssertionID else { return }
            client.releaseAssertion(id: id)
            displayAssertionID = nil
        }
    }

    public func setPreventDiskSleep(_ enabled: Bool) throws {
        guard isEnabled else { return }

        if enabled {
            guard diskAssertionID == nil else { return }
            let diskID = try client.createDiskSleepAssertion(reason: "Adrenaline is active")
            diskAssertionID = diskID
        } else {
            guard let id = diskAssertionID else { return }
            client.releaseAssertion(id: id)
            diskAssertionID = nil
        }
    }

    public func disable() {
        if let id = diskAssertionID {
            client.releaseAssertion(id: id)
            diskAssertionID = nil
        }
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
