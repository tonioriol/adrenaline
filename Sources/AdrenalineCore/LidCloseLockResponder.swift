import Foundation
import os.log

/// Handles what the screen does when the lid closes while Adrenaline is on:
/// the display is always allowed to sleep (a lit panel inside a closed lid is useless),
/// and the Mac locks like native macOS unless "Stay unlocked when lid is closed" is in effect.
public final class LidCloseLockResponder {
    private static let log = OSLog(subsystem: "com.tonioriol.adrenaline", category: "LidCloseLockResponder")

    private let state: AppState
    private let monitor: LidStateMonitoring
    private let screenLocker: ScreenLocking
    private let preferences: PreferencesProviding
    private let policyReader: MacOSLockPolicyReading
    private let awakeController: AwakeControlling?
    private let isStayingUnlocked: () -> Bool
    private let displaySleeper: DisplaySleeping?

    public init(
        state: AppState,
        monitor: LidStateMonitoring,
        screenLocker: ScreenLocking,
        preferences: PreferencesProviding,
        policyReader: MacOSLockPolicyReading,
        awakeController: AwakeControlling? = nil,
        isStayingUnlocked: @escaping () -> Bool = { false },
        displaySleeper: DisplaySleeping? = nil
    ) {
        self.state = state
        self.monitor = monitor
        self.screenLocker = screenLocker
        self.preferences = preferences
        self.policyReader = policyReader
        self.awakeController = awakeController
        self.isStayingUnlocked = isStayingUnlocked
        self.displaySleeper = displaySleeper

        let existing = monitor.onLidStateChange
        monitor.onLidStateChange = { [weak self] lidState in
            existing?(lidState)
            self?.handle(lidState)
        }
    }

    private func handle(_ lidState: LidState) {
        guard state.isActive else { return }

        switch lidState {
        case .closed:
            setDisplaySleepPrevented(false)
            lockOnLidCloseIfNeeded()
            // With system sleep disabled, closing the lid does not turn the panel off by itself.
            displaySleeper?.sleepDisplayNow()
        case .open:
            setDisplaySleepPrevented(preferences.preventDisplaySleep)
        }
    }

    private func setDisplaySleepPrevented(_ prevented: Bool) {
        do {
            try awakeController?.setPreventDisplaySleep(prevented)
        } catch {
            os_log(
                "Display sleep assertion update failed: %{public}s",
                log: Self.log,
                type: .error,
                error.localizedDescription
            )
        }
    }

    private func lockOnLidCloseIfNeeded() {
        guard !isStayingUnlocked() else { return }

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
}

public protocol DisplaySleeping: AnyObject {
    func sleepDisplayNow()
}

/// Turns the display off immediately via `pmset displaysleepnow` (no root needed).
public final class PmsetDisplaySleeper: DisplaySleeping {
    public init() {}

    public func sleepDisplayNow() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }
}
