import XCTest
@testable import AdrenalineCore

private final class FakeLidStateMonitor: LidStateMonitoring {
    var onLidStateChange: ((LidState) -> Void)?
    private(set) var isMonitoring = false
    var startCallCount = 0
    var stopCallCount = 0
    var startError: Error?
    var currentLidState: LidState?

    func start() throws {
        startCallCount += 1
        if let startError { throw startError }
        isMonitoring = true
    }

    func stop() {
        stopCallCount += 1
        isMonitoring = false
    }

    func emit(_ lidState: LidState) {
        onLidStateChange?(lidState)
    }
}

private final class FakeLidSoundPlayer: LidSoundPlaying {
    private(set) var playedSoundNames: [String] = []

    func play(named soundName: String) {
        playedSoundNames.append(soundName)
    }
}

private final class FakePreferencesStore: PreferencesProviding {
    var preventDisplaySleep: Bool = true
    var preventLidCloseSleep: Bool = false
    var preventDiskSleep: Bool = true
    var playLidEventSounds: Bool = true
    var overrideSystemVolumeForLidEventSounds: Bool = true
    var lidClosePreventionConfirmed: Bool = false
    var wasActive: Bool = false

    func snapshot() -> PreferencesSnapshot {
        PreferencesSnapshot(
            preventDisplaySleep: preventDisplaySleep,
            preventLidCloseSleep: preventLidCloseSleep,
            preventDiskSleep: preventDiskSleep,
            playLidEventSounds: playLidEventSounds,
            overrideSystemVolumeForLidEventSounds: overrideSystemVolumeForLidEventSounds
        )
    }
}

private struct TestError: Error, LocalizedError {
    let errorDescription: String?
}

final class LidEventSoundControllerTests: XCTestCase {
    func testBecomingActiveStartsMonitoring() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: FakePreferencesStore())

        state.setActive(true)

        XCTAssertTrue(monitor.isMonitoring)
        XCTAssertEqual(monitor.startCallCount, 1)
        XCTAssertTrue(player.playedSoundNames.isEmpty)
        _ = controller
    }

    func testCloseEventWhileActivePlaysHero() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: prefs)

        state.setActive(true)
        monitor.emit(.closed)

        XCTAssertEqual(player.playedSoundNames, ["Hero"])
        _ = controller
    }

    func testOpenEventWhileActivePlaysBasso() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: prefs)

        state.setActive(true)
        monitor.emit(.open)

        XCTAssertEqual(player.playedSoundNames, ["Basso"])
        _ = controller
    }

    func testLidEventsWhileInactivePlayNoSounds() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: FakePreferencesStore())

        monitor.emit(.closed)
        monitor.emit(.open)

        XCTAssertTrue(player.playedSoundNames.isEmpty)
        XCTAssertFalse(monitor.isMonitoring)
        _ = controller
    }

    func testDuplicateLidStatesDoNotReplaySounds() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: prefs)

        state.setActive(true)
        monitor.emit(.closed)
        monitor.emit(.closed)
        monitor.emit(.open)
        monitor.emit(.open)
        monitor.emit(.closed)

        XCTAssertEqual(player.playedSoundNames, ["Hero", "Basso", "Hero"])
        _ = controller
    }

    func testDeactivationStopsMonitoringAndClearsDuplicateState() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: prefs)

        state.setActive(true)
        monitor.emit(.closed)
        state.setActive(false)
        XCTAssertFalse(monitor.isMonitoring)

        state.setActive(true)
        monitor.emit(.closed)

        XCTAssertTrue(monitor.isMonitoring)
        XCTAssertEqual(player.playedSoundNames, ["Hero", "Hero"])
        _ = controller
    }

    func testMonitorStartFailureDoesNotChangeAppStateOrPlaySounds() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        monitor.startError = TestError(errorDescription: "monitor unavailable")
        let player = FakeLidSoundPlayer()
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: FakePreferencesStore())

        state.setActive(true)
        monitor.emit(.closed)

        XCTAssertTrue(state.isActive)
        XCTAssertFalse(state.isBusy)
        XCTAssertNil(state.lastErrorMessage)
        XCTAssertEqual(state.helperState, .unknown)
        XCTAssertFalse(monitor.isMonitoring)
        XCTAssertTrue(player.playedSoundNames.isEmpty)
        _ = controller
    }

    func testPlayLidEventSoundsOffSilencesBothEvents() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let prefs = FakePreferencesStore()
        prefs.playLidEventSounds = false
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: prefs)

        state.setActive(true)
        monitor.emit(.closed)
        monitor.emit(.open)

        XCTAssertTrue(player.playedSoundNames.isEmpty)
        _ = controller
    }

    func testPreventLidCloseSleepOffSilencesEventsEvenWhenSoundsEnabled() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = false
        prefs.playLidEventSounds = true
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: prefs)

        state.setActive(true)
        monitor.emit(.closed)
        monitor.emit(.open)

        XCTAssertTrue(player.playedSoundNames.isEmpty)
        _ = controller
    }

    func testTogglingPlayLidEventSoundsBetweenEventsAffectsOnlyNextEvent() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: prefs)

        state.setActive(true)
        monitor.emit(.closed)
        prefs.playLidEventSounds = false
        monitor.emit(.open)
        prefs.playLidEventSounds = true
        monitor.emit(.closed)

        XCTAssertEqual(player.playedSoundNames, ["Hero", "Hero"])
        _ = controller
    }

    func testMutedDuplicateLidStateDoesNotReplayAfterSoundsReenabled() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let prefs = FakePreferencesStore()
        prefs.playLidEventSounds = false
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: prefs)

        state.setActive(true)
        monitor.emit(.closed)
        prefs.playLidEventSounds = true
        monitor.emit(.closed)

        XCTAssertTrue(player.playedSoundNames.isEmpty, "Re-enabling sounds must not replay a duplicate of a state already handled while muted")
        _ = controller
    }

    func testFirstSpuriousLidEventMatchingCurrentStateIsSuppressed() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        monitor.currentLidState = .open
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: prefs)

        state.setActive(true)

        monitor.emit(.open)

        XCTAssertTrue(
            player.playedSoundNames.isEmpty,
            "A spurious lid notification matching the actual lid state (e.g. on display dim/wake) must not play a sound"
        )
        _ = controller
    }

    func testRealLidCloseAfterSeededOpenStillPlaysHero() {
        let state = AppState()
        let monitor = FakeLidStateMonitor()
        let player = FakeLidSoundPlayer()
        let prefs = FakePreferencesStore()
        prefs.preventLidCloseSleep = true
        monitor.currentLidState = .open
        let controller = LidEventSoundController(state: state, monitor: monitor, soundPlayer: player, preferences: prefs)

        state.setActive(true)
        monitor.emit(.closed)

        XCTAssertEqual(player.playedSoundNames, ["Hero"])
        _ = controller
    }
}
