import Combine
import Foundation

public enum LidState: Equatable, Sendable {
    case open
    case closed
}

@MainActor
public protocol LidStateMonitoring: AnyObject {
    var onLidStateChange: (@MainActor (LidState) -> Void)? { get set }
    var isMonitoring: Bool { get }
    func start() throws
    func stop()
}

@MainActor
public protocol LidSoundPlaying: AnyObject {
    func play(named soundName: String)
}

@MainActor
public final class LidEventSoundController {
    public static let closeSoundName = "Hero"
    public static let openSoundName = "Basso"

    private let state: AppState
    private let monitor: LidStateMonitoring
    private let soundPlayer: LidSoundPlaying
    private var cancellable: AnyCancellable?
    private var lastHandledState: LidState?
    private var monitoringStarted = false

    public init(
        state: AppState,
        monitor: LidStateMonitoring,
        soundPlayer: LidSoundPlaying
    ) {
        self.state = state
        self.monitor = monitor
        self.soundPlayer = soundPlayer

        monitor.onLidStateChange = { [weak self] lidState in
            self?.handle(lidState)
        }

        cancellable = state.$isActive
            .removeDuplicates()
            .sink { [weak self] isActive in
                self?.setMonitoringEnabled(isActive)
            }
    }

    private func setMonitoringEnabled(_ enabled: Bool) {
        if enabled {
            do {
                try monitor.start()
                monitoringStarted = true
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

        switch lidState {
        case .closed:
            soundPlayer.play(named: Self.closeSoundName)
        case .open:
            soundPlayer.play(named: Self.openSoundName)
        }

        lastHandledState = lidState
    }
}
