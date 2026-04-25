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
    }

    func testRecordingErrorKeepsFeatureInactive() {
        let state = AppState()

        state.setActive(true)
        state.recordError("helper failed")

        XCTAssertFalse(state.isActive)
        XCTAssertEqual(state.lastErrorMessage, "helper failed")
    }
}
