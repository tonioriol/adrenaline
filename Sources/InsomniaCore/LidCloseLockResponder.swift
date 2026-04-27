import Foundation
import os.log

@MainActor
public final class LidCloseLockResponder {
    private static let log = OSLog(subsystem: "com.tonioriol.insomnia", category: "LidCloseLockResponder")

    private let state: AppState
    private let monitor: LidStateMonitoring
    private let screenLocker: ScreenLocking
    private let preferences: PreferencesProviding
    private let policyReader: MacOSLockPolicyReading

    public init(
        state: AppState,
        monitor: LidStateMonitoring,
        screenLocker: ScreenLocking,
        preferences: PreferencesProviding,
        policyReader: MacOSLockPolicyReading
    ) {
        self.state = state
        self.monitor = monitor
        self.screenLocker = screenLocker
        self.preferences = preferences
        self.policyReader = policyReader

        let existing = monitor.onLidStateChange
        monitor.onLidStateChange = { [weak self] lidState in
            existing?(lidState)
            self?.handle(lidState)
        }
    }

    private func handle(_ lidState: LidState) {
        guard lidState == .closed else { return }
        lockOnLidCloseIfNeeded()
    }

    private func lockOnLidCloseIfNeeded() {
        guard shouldLockOnLidClose else { return }

        do {
            let policy = try policyReader.currentPolicy()
            guard policy.requiresPassword else { return }
            try screenLocker.lock()
        } catch {
            os_log(
                "Lid-close lock failed: %{public}s",
                log: Self.log,
                type: .error,
                error.localizedDescription
            )
        }
    }

    private var shouldLockOnLidClose: Bool {
        state.isActive && !preferences.preventDisplaySleep
    }
}
