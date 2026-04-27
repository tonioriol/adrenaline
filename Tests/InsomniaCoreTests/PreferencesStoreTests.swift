import Combine
import XCTest
@testable import InsomniaCore

@MainActor
final class PreferencesStoreTests: XCTestCase {
    private func makeIsolatedDefaults(file: StaticString = #file, line: UInt = #line) -> UserDefaults {
        let suiteName = "InsomniaTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create test UserDefaults suite", file: file, line: line)
            return UserDefaults.standard
        }
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    func testEmptyDefaultsYieldSpecDefaults() {
        let defaults = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: defaults)

        XCTAssertTrue(store.preventDisplaySleep)
        XCTAssertFalse(store.preventLidCloseSleep)
        XCTAssertTrue(store.lockScreenOnLidClose)
        XCTAssertTrue(store.playLidEventSounds)
        XCTAssertFalse(store.lidClosePreventionConfirmed)
    }

    func testEachPreferenceRoundTripsThroughUserDefaults() {
        let defaults = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: defaults)

        store.preventDisplaySleep = false
        store.preventLidCloseSleep = true
        store.lockScreenOnLidClose = false
        store.playLidEventSounds = false
        store.lidClosePreventionConfirmed = true

        let reloaded = PreferencesStore(defaults: defaults)
        XCTAssertFalse(reloaded.preventDisplaySleep)
        XCTAssertTrue(reloaded.preventLidCloseSleep)
        XCTAssertFalse(reloaded.lockScreenOnLidClose)
        XCTAssertFalse(reloaded.playLidEventSounds)
        XCTAssertTrue(reloaded.lidClosePreventionConfirmed)
    }

    func testSnapshotMirrorsCurrentValues() {
        let defaults = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: defaults)

        store.preventDisplaySleep = false
        store.preventLidCloseSleep = true
        store.lockScreenOnLidClose = false
        store.playLidEventSounds = false

        let snapshot = store.snapshot()
        XCTAssertFalse(snapshot.preventDisplaySleep)
        XCTAssertTrue(snapshot.preventLidCloseSleep)
        XCTAssertFalse(snapshot.lockScreenOnLidClose)
        XCTAssertFalse(snapshot.playLidEventSounds)
    }

    func testPreferencePublisherEmitsOnChange() {
        let defaults = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: defaults)
        var seen: [Bool] = []
        let cancellable = store.$preventLidCloseSleep.sink { seen.append($0) }

        store.preventLidCloseSleep = true
        store.preventLidCloseSleep = false

        XCTAssertEqual(seen, [false, true, false])
        cancellable.cancel()
    }
}
