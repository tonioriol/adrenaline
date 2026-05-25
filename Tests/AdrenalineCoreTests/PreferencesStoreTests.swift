import XCTest
@testable import AdrenalineCore

@MainActor
final class PreferencesStoreTests: XCTestCase {
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

    func testChangingEachPreferencePostsItsMatchingNotification() {
        let defaults = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: defaults)
        let displayDidChange = Notification.Name("Adrenaline.preferencesPreventDisplaySleepDidChange")
        let lidDidChange = Notification.Name("Adrenaline.preferencesPreventLidCloseSleepDidChange")
        let soundDidChange = Notification.Name("Adrenaline.preferencesPlayLidEventSoundsDidChange")

        let counts = observeNotifications(
            named: [displayDidChange, lidDidChange, soundDidChange],
            from: store
        ) {
            store.preventDisplaySleep = false
            store.preventLidCloseSleep = true
            store.playLidEventSounds = false
        }

        XCTAssertEqual(counts[displayDidChange], 1)
        XCTAssertEqual(counts[lidDidChange], 1)
        XCTAssertEqual(counts[soundDidChange], 1)
    }

    func testSettingSamePreventLidCloseSleepValueDoesNotPostNotification() {
        let defaults = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: defaults)
        let lidDidChange = Notification.Name("Adrenaline.preferencesPreventLidCloseSleepDidChange")

        let counts = observeNotifications(named: [lidDidChange], from: store) {
            store.preventLidCloseSleep = false
            store.preventLidCloseSleep = true
            store.preventLidCloseSleep = true
        }

        XCTAssertEqual(counts[lidDidChange], 1)
    }
}
