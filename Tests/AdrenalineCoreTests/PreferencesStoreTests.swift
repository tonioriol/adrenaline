import Combine
import XCTest
@testable import AdrenalineCore

@MainActor
final class PreferencesStoreTests: XCTestCase {
    private func makeIsolatedDefaults(file: StaticString = #file, line: UInt = #line) -> UserDefaults {
        let suiteName = "AdrenalineTests.\(UUID().uuidString)"
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
        XCTAssertTrue(store.playLidEventSounds)
        XCTAssertFalse(store.lidClosePreventionConfirmed)
    }

    func testEachPreferenceRoundTripsThroughUserDefaults() {
        let defaults = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: defaults)

        store.preventDisplaySleep = false
        store.preventLidCloseSleep = true
        store.playLidEventSounds = false
        store.lidClosePreventionConfirmed = true

        let reloaded = PreferencesStore(defaults: defaults)
        XCTAssertFalse(reloaded.preventDisplaySleep)
        XCTAssertTrue(reloaded.preventLidCloseSleep)
        XCTAssertFalse(reloaded.playLidEventSounds)
        XCTAssertTrue(reloaded.lidClosePreventionConfirmed)
    }

    func testWasActiveDefaultsToFalse() {
        let defaults = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: defaults)
        XCTAssertFalse(store.wasActive)
    }

    func testWasActiveRoundTripsThroughUserDefaults() {
        let defaults = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: defaults)

        store.wasActive = true

        let reloaded = PreferencesStore(defaults: defaults)
        XCTAssertTrue(reloaded.wasActive)
    }

    func testSnapshotMirrorsCurrentValues() {
        let defaults = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: defaults)

        store.preventDisplaySleep = false
        store.preventLidCloseSleep = true
        store.playLidEventSounds = false

        let snapshot = store.snapshot()
        XCTAssertFalse(snapshot.preventDisplaySleep)
        XCTAssertTrue(snapshot.preventLidCloseSleep)
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
