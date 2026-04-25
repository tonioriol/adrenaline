import Combine
import Foundation
import os.log

@MainActor
public final class LidCloseLockResponder {
    private static let log = OSLog(subsystem: "com.tr0n.Cocaine", category: "LidCloseLockResponder")

    private let state: AppState
    private let monitor: LidStateMonitoring
    private let screenLocker: ScreenLocking
    private let preferences: PreferencesProviding

    public init(
        state: AppState,
        monitor: LidStateMonitoring,
        screenLocker: ScreenLocking,
        preferences: PreferencesProviding
    ) {
        self.state = state
        self.monitor = monitor
        self.screenLocker = screenLocker
        self.preferences = preferences

        let existing = monitor.onLidStateChange
        monitor.onLidStateChange = { [weak self] lidState in
            existing?(lidState)
            self?.handle(lidState)
        }
    }

    private func handle(_ lidState: LidState) {
        guard lidState == .closed else { return }
        guard state.isActive else { return }
        guard preferences.preventLidCloseSleep else { return }
        guard preferences.lockScreenOnLidClose else { return }

        do {
            try screenLocker.lock()
        } catch {
            os_log("Screen lock failed: %{public}s",
                   log: Self.log,
                   type: .error,
                   error.localizedDescription)
        }
    }
}
