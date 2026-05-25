import XCTest
@testable import AdrenalineCore

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

    func installOrUpdateHelperIfNeeded(completion: @escaping (Error?) -> Void) {
        installCallCount += 1
        if let installError {
            completion(installError)
            return
        }
        installed = true
        completion(nil)
    }

    func enableLidClosePrevention(completion: @escaping (Error?) -> Void) {
        enableCallCount += 1
        if let enableError {
            completion(enableError)
            return
        }
        enabled = true
        completion(nil)
    }

    func disableLidClosePrevention(completion: @escaping (Error?) -> Void) {
        disableCallCount += 1
        if let disableError {
            completion(disableError)
            return
        }
        enabled = false
        completion(nil)
    }

    func readLidClosePreventionStatus(completion: @escaping (Result<Bool, Error>) -> Void) {
        statusCallCount += 1
        completion(.success(enabled))
    }
}

private struct TestError: Error, LocalizedError {
    let errorDescription: String?
}

final class LidCloseControllerTests: XCTestCase {
    func testEnableInstallsHelperThenEnablesLidClosePrevention() {
        let helper = FakePrivilegedHelperClient()
        let controller = LidCloseController(helperClient: helper)
        var receivedError: Error?

        controller.enable { receivedError = $0 }

        XCTAssertNil(receivedError)
        XCTAssertTrue(helper.installed)
        XCTAssertTrue(helper.enabled)
        XCTAssertEqual(helper.installCallCount, 1)
        XCTAssertEqual(helper.enableCallCount, 1)
    }

    func testEnableDoesNotEnableWhenInstallFails() {
        let helper = FakePrivilegedHelperClient()
        helper.installError = TestError(errorDescription: "install failed")
        let controller = LidCloseController(helperClient: helper)
        var receivedError: Error?

        controller.enable { receivedError = $0 }

        XCTAssertEqual(receivedError?.localizedDescription, "install failed")
        XCTAssertFalse(helper.installed)
        XCTAssertFalse(helper.enabled)
        XCTAssertEqual(helper.installCallCount, 1)
        XCTAssertEqual(helper.enableCallCount, 0)
    }

    func testEnablePropagatesEnableFailureAfterInstall() {
        let helper = FakePrivilegedHelperClient()
        helper.enableError = TestError(errorDescription: "enable failed")
        let controller = LidCloseController(helperClient: helper)
        var receivedError: Error?

        controller.enable { receivedError = $0 }

        XCTAssertEqual(receivedError?.localizedDescription, "enable failed")
        XCTAssertTrue(helper.installed)
        XCTAssertFalse(helper.enabled)
        XCTAssertEqual(helper.installCallCount, 1)
        XCTAssertEqual(helper.enableCallCount, 1)
    }

    func testDisableForwardsToHelper() {
        let helper = FakePrivilegedHelperClient()
        helper.enabled = true
        let controller = LidCloseController(helperClient: helper)
        var receivedError: Error?

        controller.disable { receivedError = $0 }

        XCTAssertNil(receivedError)
        XCTAssertFalse(helper.enabled)
        XCTAssertEqual(helper.disableCallCount, 1)
    }

    func testStatusForwardsToHelper() {
        let helper = FakePrivilegedHelperClient()
        helper.enabled = true
        let controller = LidCloseController(helperClient: helper)
        var receivedResult: Result<Bool, Error>?

        controller.status { receivedResult = $0 }

        guard case .success(let enabled)? = receivedResult else {
            return XCTFail("Expected successful status result")
        }

        XCTAssertTrue(enabled)
        XCTAssertEqual(helper.statusCallCount, 1)
    }
}
