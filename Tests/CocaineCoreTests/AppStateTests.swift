import XCTest
@testable import CocaineCore

@MainActor
final class AppStateTests: XCTestCase {
    func testInitialStateIsInactiveAndIdle() {
        let state = AppState()

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertNil(state.lastErrorMessage)
        XCTAssertEqual(state.helperState, .unknown)
    }

    func testMarkingActiveClearsPreviousError() {
        let state = AppState()

        state.recordError("boom")
        state.setActive(true)

        XCTAssertTrue(state.isActive)
        XCTAssertNil(state.lastErrorMessage)
        XCTAssertEqual(state.helperState, .unknown)
    }

    func testRecordingErrorKeepsFeatureInactive() {
        let state = AppState()

        state.setActive(true)
        state.recordError("helper failed")

        XCTAssertFalse(state.isActive)
        XCTAssertEqual(state.lastErrorMessage, "helper failed")
    }

    func testRecordingErrorClearsBusyAndMarksHelperFailed() {
        let state = AppState(isActive: true, isBusy: true)

        state.recordError("helper failed")

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertEqual(state.lastErrorMessage, "helper failed")
        XCTAssertEqual(state.helperState, .failed(message: "helper failed"))
    }

    func testRecordErrorWhileActiveKeepsActiveButSetsErrorAndHelperFailed() {
        let state = AppState(isActive: true, isBusy: true)
        state.recordErrorWhileActive("display assertion failed")

        XCTAssertTrue(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertEqual(state.lastErrorMessage, "display assertion failed")
        XCTAssertEqual(state.helperState, .failed(message: "display assertion failed"))
    }

    func testSettingHelperFailedSynchronizesVisibleErrorAndDeactivates() {
        let state = AppState(isActive: true, isBusy: true)

        state.setHelperState(.failed(message: "helper failed"))

        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertEqual(state.lastErrorMessage, "helper failed")
        XCTAssertEqual(state.helperState, .failed(message: "helper failed"))
    }

    func testClearErrorNormalizesFailedHelperStateOnly() {
        let state = AppState()
        state.recordError("helper failed")

        state.clearError()

        XCTAssertNil(state.lastErrorMessage)
        XCTAssertEqual(state.helperState, .unknown)
    }

    func testClearErrorPreservesReadyHelperState() {
        let state = AppState(helperState: .ready(version: 1), lastErrorMessage: "old error")

        state.clearError()

        XCTAssertNil(state.lastErrorMessage)
        XCTAssertEqual(state.helperState, .ready(version: 1))
    }
}
