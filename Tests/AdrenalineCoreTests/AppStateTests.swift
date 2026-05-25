import XCTest
@testable import AdrenalineCore

@MainActor
final class AppStateTests: XCTestCase {
    private func observeNotifications(
        named names: [Notification.Name],
        from object: AnyObject,
        during operation: () -> Void
    ) -> [Notification.Name: Int] {
        var counts = Dictionary(uniqueKeysWithValues: names.map { ($0, 0) })
        let tokens = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: object, queue: nil) { _ in
                counts[name, default: 0] += 1
            }
        }

        operation()

        for token in tokens {
            NotificationCenter.default.removeObserver(token)
        }

        return counts
    }

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

    func testSetActivePostsActiveDidChangeNotification() {
        let state = AppState()

        let counts = observeNotifications(
            named: [Notification.Name("Adrenaline.appStateActiveDidChange")],
            from: state
        ) {
            state.setActive(true)
        }

        XCTAssertEqual(counts[Notification.Name("Adrenaline.appStateActiveDidChange")], 1)
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

    func testRecordingErrorPostsNotificationsForChangedProperties() {
        let state = AppState(isActive: true, isBusy: true)
        let activeDidChange = Notification.Name("Adrenaline.appStateActiveDidChange")
        let busyDidChange = Notification.Name("Adrenaline.appStateBusyDidChange")
        let errorDidChange = Notification.Name("Adrenaline.appStateErrorDidChange")
        let helperDidChange = Notification.Name("Adrenaline.appStateHelperDidChange")

        let counts = observeNotifications(
            named: [activeDidChange, busyDidChange, errorDidChange, helperDidChange],
            from: state
        ) {
            state.recordError("helper failed")
        }

        XCTAssertEqual(counts[activeDidChange], 1)
        XCTAssertEqual(counts[busyDidChange], 1)
        XCTAssertEqual(counts[errorDidChange], 1)
        XCTAssertEqual(counts[helperDidChange], 1)
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
