import XCTest
@testable import InsomniaCore

@MainActor
private final class FakeLoginItemService: LoginItemServicing {
    var status: LaunchAtLoginStatus = .disabled
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    func register() throws {
        registerCallCount += 1
        if let registerError { throw registerError }
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError { throw unregisterError }
        status = .disabled
    }
}

private struct LaunchAtLoginTestError: Error, LocalizedError {
    let errorDescription: String?
}

@MainActor
final class LaunchAtLoginControllerTests: XCTestCase {
    func testIsEnabledReflectsServiceStatus() {
        let service = FakeLoginItemService()
        let controller = LaunchAtLoginController(service: service)

        service.status = .disabled
        XCTAssertFalse(controller.isEnabled)

        service.status = .enabled
        XCTAssertTrue(controller.isEnabled)

        service.status = .requiresApproval
        XCTAssertFalse(controller.isEnabled)

        service.status = .unavailable
        XCTAssertFalse(controller.isEnabled)
    }

    func testStatusReflectsServiceStatus() {
        let service = FakeLoginItemService()
        let controller = LaunchAtLoginController(service: service)

        service.status = .disabled
        XCTAssertEqual(controller.status, .disabled)

        service.status = .enabled
        XCTAssertEqual(controller.status, .enabled)

        service.status = .requiresApproval
        XCTAssertEqual(controller.status, .requiresApproval)

        service.status = .unavailable
        XCTAssertEqual(controller.status, .unavailable)
    }

    func testSetEnabledRegistersWhenCurrentlyDisabled() throws {
        let service = FakeLoginItemService()
        service.status = .disabled
        let controller = LaunchAtLoginController(service: service)

        try controller.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(service.status, .enabled)
        XCTAssertTrue(controller.isEnabled)
    }

    func testSetEnabledDoesNothingWhenAlreadyEnabled() throws {
        let service = FakeLoginItemService()
        service.status = .enabled
        let controller = LaunchAtLoginController(service: service)

        try controller.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertTrue(controller.isEnabled)
    }

    func testSetDisabledUnregistersWhenEnabled() throws {
        let service = FakeLoginItemService()
        service.status = .enabled
        let controller = LaunchAtLoginController(service: service)

        try controller.setEnabled(false)

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(service.status, .disabled)
        XCTAssertFalse(controller.isEnabled)
    }

    func testSetDisabledUnregistersWhenRequiresApproval() throws {
        let service = FakeLoginItemService()
        service.status = .requiresApproval
        let controller = LaunchAtLoginController(service: service)

        try controller.setEnabled(false)

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(service.status, .disabled)
        XCTAssertFalse(controller.isEnabled)
    }

    func testSetDisabledDoesNothingWhenAlreadyDisabled() throws {
        let service = FakeLoginItemService()
        service.status = .disabled
        let controller = LaunchAtLoginController(service: service)

        try controller.setEnabled(false)

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertFalse(controller.isEnabled)
    }

    func testSetDisabledDoesNothingWhenUnavailable() throws {
        let service = FakeLoginItemService()
        service.status = .unavailable
        let controller = LaunchAtLoginController(service: service)

        try controller.setEnabled(false)

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertFalse(controller.isEnabled)
    }

    func testRegisterFailurePropagatesAndLeavesStatusUnchanged() {
        let service = FakeLoginItemService()
        service.status = .disabled
        service.registerError = LaunchAtLoginTestError(errorDescription: "registration failed")
        let controller = LaunchAtLoginController(service: service)

        XCTAssertThrowsError(try controller.setEnabled(true)) { error in
            XCTAssertEqual(error.localizedDescription, "registration failed")
        }

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(service.status, .disabled)
        XCTAssertFalse(controller.isEnabled)
    }

    func testUnregisterFailurePropagatesAndLeavesStatusUnchanged() {
        let service = FakeLoginItemService()
        service.status = .enabled
        service.unregisterError = LaunchAtLoginTestError(errorDescription: "unregistration failed")
        let controller = LaunchAtLoginController(service: service)

        XCTAssertThrowsError(try controller.setEnabled(false)) { error in
            XCTAssertEqual(error.localizedDescription, "unregistration failed")
        }

        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(service.status, .enabled)
        XCTAssertTrue(controller.isEnabled)
    }
}
