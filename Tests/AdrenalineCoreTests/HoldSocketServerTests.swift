import XCTest
@testable import AdrenalineCore

final class HoldSocketServerTests: XCTestCase {
    private var path: String!
    private var state: AppState!
    private var holds: HoldController!
    private var server: HoldSocketServer!

    override func setUpWithError() throws {
        // sun_path is limited to 104 bytes, so keep it short.
        path = "/tmp/adr-\(UUID().uuidString.prefix(8)).sock"
        state = AppState()
        let coordinator = FakeHoldCoordinator(state: state)
        holds = HoldController(state: state, coordinator: coordinator)
        server = HoldSocketServer(path: path, holds: holds, state: state)
        try server.start()
    }

    override func tearDown() {
        server.stop()
    }

    /// Runs a blocking client call off the main queue while the main run loop serves it.
    private func call(_ client: HoldSocketClient, _ body: [String: Any]) throws -> [String: Any] {
        var result: Result<[String: Any], Error>?
        DispatchQueue.global().async {
            result = Result { try client.request(body) }
        }
        let deadline = Date().addingTimeInterval(5)
        while result == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return try XCTUnwrap(result).get()
    }

    private func spin(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    func testSocketIsOwnerOnly() throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testHoldActivatesAndClosingConnectionReleases() throws {
        var client: HoldSocketClient? = try HoldSocketClient(path: path)
        let response = try call(client!, ["cmd": "hold", "reason": "roo task"])
        XCTAssertEqual(response["ok"] as? Bool, true)
        XCTAssertTrue(state.isActive)

        let status = try call(client!, ["cmd": "status"])
        XCTAssertEqual(status["active"] as? Bool, true)
        XCTAssertEqual(status["holdDriven"] as? Bool, true)
        let list = try XCTUnwrap(status["holds"] as? [[String: Any]])
        XCTAssertEqual(list.first?["reason"] as? String, "roo task")
        XCTAssertEqual(list.first?["pid"] as? Int, Int(getpid()), "peer pid is recorded")

        client = nil // closes the socket, like a crashed caller
        spin { !state.isActive }
        XCTAssertFalse(state.isActive)
        XCTAssertTrue(holds.holds.isEmpty)
    }

    func testExplicitReleaseAndRepeatedHoldKeepOneHold() throws {
        let client = try HoldSocketClient(path: path)
        _ = try call(client, ["cmd": "hold"])
        _ = try call(client, ["cmd": "hold"])
        XCTAssertEqual(holds.holds.count, 1)
        _ = try call(client, ["cmd": "release"])
        XCTAssertTrue(holds.holds.isEmpty)
        XCTAssertFalse(state.isActive)
    }

    func testBadRequestsGetErrors() throws {
        let client = try HoldSocketClient(path: path)
        let unknown = try call(client, ["cmd": "nope"])
        XCTAssertEqual(unknown["ok"] as? Bool, false)
        let missing = try call(client, ["foo": 1])
        XCTAssertEqual(missing["ok"] as? Bool, false)
    }
}
