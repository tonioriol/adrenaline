import Foundation

/// Remembers the user's on/off choice in `wasActive` so a relaunch restores it.
/// Ignores activations made for external holds and the turn-off done while quitting.
public final class ActiveStateRecorder {
    private var observer: NSObjectProtocol?

    public init(
        state: AppState,
        preferences: PreferencesProviding,
        coordinator: AppCoordinator,
        isHoldDriven: @escaping () -> Bool
    ) {
        observer = NotificationCenter.default.addObserver(
            forName: .appStateActiveDidChange,
            object: state,
            queue: nil
        ) { [weak state, weak coordinator] _ in
            guard let isActive = state?.isActive else { return }
            // Quitting (including restart/logout) turns off without the user asking.
            if coordinator?.isShuttingDown == true { return }
            // Don't remember activations made on behalf of external holds.
            if isActive, isHoldDriven() { return }
            preferences.wasActive = isActive
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}
