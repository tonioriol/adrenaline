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
    private let scheduler: LidCloseLockScheduling
    private var pendingLock: LidCloseLockCancellable?

    public init(
        state: AppState,
        monitor: LidStateMonitoring,
        screenLocker: ScreenLocking,
        preferences: PreferencesProviding,
        policyReader: MacOSLockPolicyReading,
        scheduler: LidCloseLockScheduling? = nil
    ) {
        self.state = state
        self.monitor = monitor
        self.screenLocker = screenLocker
        self.preferences = preferences
        self.policyReader = policyReader
        self.scheduler = scheduler ?? TaskLidCloseLockScheduler()

        let existing = monitor.onLidStateChange
        monitor.onLidStateChange = { [weak self] lidState in
            existing?(lidState)
            self?.handle(lidState)
        }
    }

    deinit {
        MainActor.assumeIsolated {
            pendingLock?.cancel()
        }
    }

    private func handle(_ lidState: LidState) {
        switch lidState {
        case .open:
            cancelPendingLock()
        case .closed:
            scheduleLockIfNeeded()
        }
    }

    private func scheduleLockIfNeeded() {
        cancelPendingLock()

        guard shouldLockIfTimerFires else { return }

        do {
            let policy = try policyReader.currentPolicy()
            guard let delay = policy.lockDelay else { return }

            pendingLock = scheduler.schedule(after: delay) { [weak self] in
                self?.lockIfStillNeeded()
            }
        } catch {
            os_log(
                "Could not read macOS lock policy: %{public}s",
                log: Self.log,
                type: .error,
                error.localizedDescription
            )
        }
    }

    private func lockIfStillNeeded() {
        pendingLock = nil

        guard shouldLockIfTimerFires else { return }
        guard monitor.currentLidState == .closed else { return }

        do {
            try screenLocker.lock()
        } catch {
            os_log(
                "Screen lock failed: %{public}s",
                log: Self.log,
                type: .error,
                error.localizedDescription
            )
        }
    }

    private var shouldLockIfTimerFires: Bool {
        state.isActive && preferences.preventLidCloseSleep && !preferences.preventDisplaySleep
    }

    private func cancelPendingLock() {
        pendingLock?.cancel()
        pendingLock = nil
    }
}
