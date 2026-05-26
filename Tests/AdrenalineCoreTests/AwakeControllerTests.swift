import XCTest
@testable import AdrenalineCore

private final class FakePowerAssertionClient: PowerAssertionClient {
    var nextID: UInt32 = 41
    var createdReasons: [String] = []
    var createdAssertionTypes: [String] = []
    var releasedIDs: [UInt32] = []
    var createError: Error?
    var displayCreateError: Error?
    var diskCreateError: Error?

    func createNoIdleSleepAssertion(reason: String) throws -> UInt32 {
        if let createError { throw createError }
        createdReasons.append(reason)
        createdAssertionTypes.append("system")
        nextID += 1
        return nextID
    }

    func createDisplaySleepAssertion(reason: String) throws -> UInt32 {
        if let createError { throw createError }
        if let displayCreateError { throw displayCreateError }
        createdReasons.append(reason)
        createdAssertionTypes.append("display")
        nextID += 1
        return nextID
    }

    func createDiskSleepAssertion(reason: String) throws -> UInt32 {
        if let createError { throw createError }
        if let diskCreateError { throw diskCreateError }
        createdReasons.append(reason)
        createdAssertionTypes.append("disk")
        nextID += 1
        return nextID
    }

    func releaseAssertion(id: UInt32) {
        releasedIDs.append(id)
    }
}

private struct TestError: LocalizedError {
    var errorDescription: String?
}

final class AwakeControllerTests: XCTestCase {
    func testEnableCreatesSystemAndDisplayAssertions() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable(preventDisplaySleep: true)

        XCTAssertEqual(client.createdReasons, ["Adrenaline is active", "Adrenaline is active"])
        XCTAssertTrue(controller.isEnabled)
    }

    func testEnableWithoutDisplayFlagCreatesOnlyNoIdleAssertion() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable(preventDisplaySleep: false)

        XCTAssertEqual(client.createdReasons, ["Adrenaline is active"])
        XCTAssertTrue(controller.isEnabled)
    }

    func testEnableWithDisplayFlagCreatesBothAssertions() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable(preventDisplaySleep: true)

        XCTAssertEqual(client.createdReasons, ["Adrenaline is active", "Adrenaline is active"])
        XCTAssertTrue(controller.isEnabled)
    }

    func testEnableWithDisplayAndDiskFlagsCreatesAllAssertions() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable(preventDisplaySleep: true, preventDiskSleep: true)

        XCTAssertEqual(client.createdAssertionTypes, ["system", "display", "disk"])
        XCTAssertTrue(controller.isEnabled)
    }

    func testSetPreventDisplaySleepReleasesDisplayAssertionWhenTurnedOff() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable(preventDisplaySleep: true)
        try controller.setPreventDisplaySleep(false)

        XCTAssertEqual(client.releasedIDs, [43])
        XCTAssertTrue(controller.isEnabled)
    }

    func testSetPreventDisplaySleepCreatesDisplayAssertionWhenTurnedOn() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable(preventDisplaySleep: false)
        try controller.setPreventDisplaySleep(true)

        XCTAssertEqual(client.createdReasons, ["Adrenaline is active", "Adrenaline is active"])
        XCTAssertTrue(controller.isEnabled)
    }

    func testSetPreventDisplaySleepIsNoopWhenDisabled() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.setPreventDisplaySleep(true)

        XCTAssertTrue(client.createdReasons.isEmpty)
        XCTAssertFalse(controller.isEnabled)
    }

    func testSetPreventDisplaySleepRevertsOnDisplayCreationFailure() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)
        try controller.enable(preventDisplaySleep: false)

        client.displayCreateError = TestError(errorDescription: "display failed")
        XCTAssertThrowsError(try controller.setPreventDisplaySleep(true))

        XCTAssertEqual(client.createdReasons, ["Adrenaline is active"])
        XCTAssertTrue(controller.isEnabled)
    }

    func testSetPreventDiskSleepReleasesDiskAssertionWhenTurnedOff() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable(preventDisplaySleep: true, preventDiskSleep: true)
        try controller.setPreventDiskSleep(false)

        XCTAssertEqual(client.releasedIDs, [44])
        XCTAssertTrue(controller.isEnabled)
    }

    func testSetPreventDiskSleepCreatesDiskAssertionWhenTurnedOn() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable(preventDisplaySleep: false, preventDiskSleep: false)
        try controller.setPreventDiskSleep(true)

        XCTAssertEqual(client.createdAssertionTypes, ["system", "disk"])
        XCTAssertTrue(controller.isEnabled)
    }

    func testSetPreventDiskSleepIsNoopWhenDisabled() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.setPreventDiskSleep(true)

        XCTAssertTrue(client.createdReasons.isEmpty)
        XCTAssertFalse(controller.isEnabled)
    }

    func testDisableReleasesCreatedAssertions() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable()
        controller.disable()

        XCTAssertEqual(client.releasedIDs, [43, 42])
        XCTAssertFalse(controller.isEnabled)
    }

    func testDisableReleasesDiskAssertionBeforeOtherAssertions() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable(preventDisplaySleep: true, preventDiskSleep: true)
        controller.disable()

        XCTAssertEqual(client.releasedIDs, [44, 43, 42])
        XCTAssertFalse(controller.isEnabled)
    }

    func testEnableIsIdempotent() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable()
        try controller.enable()

        XCTAssertEqual(client.createdReasons.count, 2)
        XCTAssertTrue(controller.isEnabled)
    }

    func testEnableReleasesSystemAssertionWhenDisplayAssertionFails() throws {
        let client = FakePowerAssertionClient()
        client.displayCreateError = TestError(errorDescription: "display failed")
        let controller = AwakeController(client: client)

        XCTAssertThrowsError(try controller.enable())

        XCTAssertEqual(client.releasedIDs, [42])
        XCTAssertFalse(controller.isEnabled)

        client.displayCreateError = nil
        try controller.enable()

        XCTAssertEqual(client.createdReasons, ["Adrenaline is active", "Adrenaline is active", "Adrenaline is active"])
        XCTAssertTrue(controller.isEnabled)
    }
}
