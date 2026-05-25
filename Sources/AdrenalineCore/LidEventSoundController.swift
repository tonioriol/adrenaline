import Foundation

public enum LidState: Equatable {
    case open
    case closed
}

public protocol LidStateMonitoring: AnyObject {
    var onLidStateChange: ((LidState) -> Void)? { get set }
    var isMonitoring: Bool { get }
    var currentLidState: LidState? { get }
    func start() throws
    func stop()
}

public protocol LidSoundPlaying: AnyObject {
    func play(named soundName: String)
}

public final class LidEventSoundController {
    public static let closeSoundName = "Hero"
    public static let openSoundName = "Basso"

    private let state: AppState
    private let monitor: LidStateMonitoring
    private let soundPlayer: LidSoundPlaying
    private let preferences: PreferencesProviding
    private var lastHandledState: LidState?
    private var monitoringStarted = false
    private var activeObserver: NSObjectProtocol?

    public init(
        state: AppState,
        monitor: LidStateMonitoring,
        soundPlayer: LidSoundPlaying,
        preferences: PreferencesProviding
    ) {
        self.state = state
        self.monitor = monitor
        self.soundPlayer = soundPlayer
        self.preferences = preferences

        monitor.onLidStateChange = { [weak self] lidState in
            self?.handle(lidState)
        }

        activeObserver = NotificationCenter.default.addObserver(
            forName: .appStateActiveDidChange,
            object: state,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.setMonitoringEnabled(self.state.isActive)
        }
    }

    deinit {
        if let observer = activeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setMonitoringEnabled(_ enabled: Bool) {
        if enabled {
            do {
                try monitor.start()
                monitoringStarted = true
                lastHandledState = monitor.currentLidState
            } catch {
                monitoringStarted = false
            }
        } else {
            monitor.stop()
            monitoringStarted = false
            lastHandledState = nil
        }
    }

    private func handle(_ lidState: LidState) {
        guard state.isActive, monitoringStarted, lidState != lastHandledState else { return }
        lastHandledState = lidState

        guard preferences.preventLidCloseSleep, preferences.playLidEventSounds else { return }

        switch lidState {
        case .closed:
            soundPlayer.play(named: Self.closeSoundName)
        case .open:
            soundPlayer.play(named: Self.openSoundName)
        }
    }
}
