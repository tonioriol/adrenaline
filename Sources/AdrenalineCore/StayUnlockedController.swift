import Foundation
import os.log

/// While Adrenaline is on with lid-close sleep prevention and "Stay unlocked when lid is closed" checked, turns the macOS
/// "Require password after display is turned off" setting off, and puts the user's own
/// setting back as soon as either stops being true. The original setting is persisted
/// before it is changed so a crash is repaired on the next launch.
public final class StayUnlockedController {
    public static let restoreKey = "Adrenaline.screenLockDelayToRestore"
    private static let log = OSLog(subsystem: "com.tonioriol.adrenaline", category: "StayUnlockedController")
    private static let maxPasswordAttempts = 3

    private let state: AppState
    private let preferences: PreferencesProviding
    private let setting: ScreenLockSettingControlling
    private let passwordStore: PasswordStoring
    private let defaults: UserDefaults
    /// Asks the user for their login password. `retry` is true after a rejected password.
    /// Returns nil when the user cancels.
    private let requestPassword: (_ retry: Bool) -> String?
    private var observers: [NSObjectProtocol] = []

    public init(
        state: AppState,
        preferences: PreferencesProviding,
        setting: ScreenLockSettingControlling,
        passwordStore: PasswordStoring,
        defaults: UserDefaults = .standard,
        requestPassword: @escaping (_ retry: Bool) -> String?
    ) {
        self.state = state
        self.preferences = preferences
        self.setting = setting
        self.passwordStore = passwordStore
        self.defaults = defaults
        self.requestPassword = requestPassword

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .appStateActiveDidChange, object: state, queue: nil) { [weak self] _ in
            self?.apply()
        })
        observers.append(center.addObserver(forName: .preferencesStayUnlockedWithLidClosedDidChange, object: nil, queue: nil) { [weak self] _ in
            self?.apply()
        })
        observers.append(center.addObserver(forName: .preferencesPreventLidCloseSleepDidChange, object: nil, queue: nil) { [weak self] _ in
            self?.apply()
        })
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public var isEngaged: Bool { savedDelay != nil }

    /// Brings the macOS setting in line with the current state. Safe to call repeatedly.
    public func apply() {
        if state.isActive && preferences.preventLidCloseSleep && preferences.stayUnlockedWithLidClosed {
            engage()
        } else {
            restore()
        }
    }

    /// Puts the user's own lock setting back, if Adrenaline changed it.
    public func restore() {
        guard let original = savedDelay else { return }
        do {
            try withPassword { password in
                try setting.setDelay(original, password: password)
            }
            savedDelay = nil
        } catch {
            report("Could not restore the macOS lock setting: \(error.localizedDescription)")
        }
    }

    private func engage() {
        guard savedDelay == nil else { return }
        do {
            let current = try setting.currentDelay()
            guard current != .off else { return }
            savedDelay = current
            do {
                try withPassword { password in
                    try setting.setDelay(.off, password: password)
                }
            } catch {
                savedDelay = nil
                throw error
            }
        } catch ScreenLockSettingError.passwordMissing {
            // The user cancelled the password prompt: nothing can be done without it.
            preferences.stayUnlockedWithLidClosed = false
        } catch {
            preferences.stayUnlockedWithLidClosed = false
            report(error.localizedDescription)
        }
    }

    /// Runs `operation` with the stored password, prompting (and saving) a new one when it
    /// is missing or rejected.
    private func withPassword(_ operation: (String) throws -> Void) throws {
        var retry = false
        var password = passwordStore.read()
        for _ in 0..<Self.maxPasswordAttempts {
            if password == nil {
                password = requestPassword(retry)
            }
            guard let candidate = password else { throw ScreenLockSettingError.passwordMissing }
            do {
                try operation(candidate)
                if passwordStore.read() != candidate {
                    try? passwordStore.save(candidate)
                }
                return
            } catch ScreenLockSettingError.changeRejected {
                password = nil
                retry = true
            }
        }
        throw ScreenLockSettingError.changeRejected("too many failed password attempts")
    }

    private var savedDelay: ScreenLockDelay? {
        get { defaults.string(forKey: Self.restoreKey).flatMap(ScreenLockDelay.init(argument:)) }
        set {
            if let newValue {
                defaults.set(newValue.argument, forKey: Self.restoreKey)
            } else {
                defaults.removeObject(forKey: Self.restoreKey)
            }
        }
    }

    private func report(_ message: String) {
        os_log("%{public}s", log: Self.log, type: .error, message)
        if state.isActive {
            state.recordErrorWhileActive(message)
        }
    }
}
