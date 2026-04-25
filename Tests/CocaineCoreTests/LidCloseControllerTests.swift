import XCTest
@testable import CocaineCore

private final class FakePrivilegedHelperClient: PrivilegedHelperClientProtocol {
    var installed = false
    var enabled = false
    var installCallCount = 0
    var enableCallCount = 0
    var disableCallCount = 0
    var statusCallCount = 0
    var installError: Error?
    var enableError: Error?
    var disableError: Error?

    func installOrUpdateHelperIfNeeded() async throws {
        installCallCount += 1
        if let installError { throw installError }
        installed = true
    }

    func enableLidClosePrevention() async throws {
        enableCallCount += 1
        if let enableError { throw enableError }
        enabled = true
    }

    func disableLidClosePrevention() async throws {
        disableCallCount += 1
        if let disableError { throw disableError }
        enabled = false
    }

    func readLidClosePreventionStatus() async throws -> Bool {
        statusCallCount += 1
        return enabled
    }
}

private struct TestError: Error, LocalizedError {
    let errorDescription: String?
}

@MainActor
final class LidCloseControllerTests: XCTestCase {
    func testEnableInstallsHelperThenEnablesLidClosePrevention() async throws {
        let helper = FakePrivilegedHelperClient()
        let controller = LidCloseController(helperClient: helper)

        try await controller.enable()

        XCTAssertTrue(helper.installed)
        XCTAssertTrue(helper.enabled)
        XCTAssertEqual(helper.installCallCount, 1)
        XCTAssertEqual(helper.enableCallCount, 1)
    }

    func testEnableDoesNotEnableWhenInstallFails() async {
        let helper = FakePrivilegedHelperClient()
        helper.installError = TestError(errorDescription: "install failed")
        let controller = LidCloseController(helperClient: helper)

        do {
            try await controller.enable()
            XCTFail("Expected enable to throw when helper installation fails")
        } catch {
            XCTAssertEqual(error.localizedDescription, "install failed")
        }

        XCTAssertFalse(helper.installed)
        XCTAssertFalse(helper.enabled)
        XCTAssertEqual(helper.installCallCount, 1)
        XCTAssertEqual(helper.enableCallCount, 0)
    }

    func testEnablePropagatesEnableFailureAfterInstall() async {
        let helper = FakePrivilegedHelperClient()
        helper.enableError = TestError(errorDescription: "enable failed")
        let controller = LidCloseController(helperClient: helper)

        do {
            try await controller.enable()
            XCTFail("Expected enable to throw when helper enable fails")
        } catch {
            XCTAssertEqual(error.localizedDescription, "enable failed")
        }

        XCTAssertTrue(helper.installed)
        XCTAssertFalse(helper.enabled)
        XCTAssertEqual(helper.installCallCount, 1)
        XCTAssertEqual(helper.enableCallCount, 1)
    }

    func testDisableForwardsToHelper() async throws {
        let helper = FakePrivilegedHelperClient()
        helper.enabled = true
        let controller = LidCloseController(helperClient: helper)

        try await controller.disable()

        XCTAssertFalse(helper.enabled)
        XCTAssertEqual(helper.disableCallCount, 1)
    }

    func testStatusForwardsToHelper() async throws {
        let helper = FakePrivilegedHelperClient()
        helper.enabled = true
        let controller = LidCloseController(helperClient: helper)

        let enabled = try await controller.status()

        XCTAssertTrue(enabled)
        XCTAssertEqual(helper.statusCallCount, 1)
    }
}
