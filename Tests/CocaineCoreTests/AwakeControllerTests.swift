import XCTest
@testable import CocaineCore

private final class FakePowerAssertionClient: PowerAssertionClient {
    var nextID: UInt32 = 41
    var createdReasons: [String] = []
    var releasedIDs: [UInt32] = []
    var createError: Error?

    func createNoIdleSleepAssertion(reason: String) throws -> UInt32 {
        if let createError { throw createError }
        createdReasons.append(reason)
        nextID += 1
        return nextID
    }

    func createDisplaySleepAssertion(reason: String) throws -> UInt32 {
        if let createError { throw createError }
        createdReasons.append(reason)
        nextID += 1
        return nextID
    }

    func releaseAssertion(id: UInt32) {
        releasedIDs.append(id)
    }
}

@MainActor
final class AwakeControllerTests: XCTestCase {
    func testEnableCreatesSystemAndDisplayAssertions() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable()

        XCTAssertEqual(client.createdReasons, ["Cocaine is active", "Cocaine is active"])
        XCTAssertTrue(controller.isEnabled)
    }

    func testDisableReleasesCreatedAssertions() throws {
        let client = FakePowerAssertionClient()
        let controller = AwakeController(client: client)

        try controller.enable()
        controller.disable()

        XCTAssertEqual(client.releasedIDs, [42, 43])
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
}
