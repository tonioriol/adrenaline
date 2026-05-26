import Foundation

public protocol AwakeControlling: AnyObject {
    func enable() throws
    func enable(preventDisplaySleep: Bool) throws
    func enable(preventDisplaySleep: Bool, preventDiskSleep: Bool) throws
    func setPreventDisplaySleep(_ enabled: Bool) throws
    func setPreventDiskSleep(_ enabled: Bool) throws
    func disable()
}

public extension AwakeControlling {
    func enable(preventDisplaySleep: Bool, preventDiskSleep: Bool) throws {
        try enable(preventDisplaySleep: preventDisplaySleep)
    }

    func setPreventDiskSleep(_ enabled: Bool) throws {}
}

public protocol LidCloseControlling: AnyObject {
    func enable(completion: @escaping (Error?) -> Void)
    func disable(completion: @escaping (Error?) -> Void)
    func status(completion: @escaping (Result<Bool, Error>) -> Void)
}

public enum AppCoordinatorError: Error, LocalizedError, Equatable {
    case lidCloseStatusDidNotBecomeActive
    case lidCloseStatusRemainedActiveAfterDisable

    public var errorDescription: String? {
        switch self {
        case .lidCloseStatusDidNotBecomeActive:
            return "Lid-close prevention did not become active"
        case .lidCloseStatusRemainedActiveAfterDisable:
            return "Lid-close prevention remained active after disable"
        }
    }
}

public final class AppCoordinator {
    private let state: AppState
    private let awakeController: AwakeControlling
    private let lidCloseController: LidCloseControlling
    private let preferences: PreferencesProviding
    private var shutdownRequested = false
    private var isTransitioning = false
    private var pendingShutdownDone: (() -> Void)?
    private var lidCloseEngagedThisSession = false

    public init(
        state: AppState,
        awakeController: AwakeControlling,
        lidCloseController: LidCloseControlling,
        preferences: PreferencesProviding
    ) {
        self.state = state
        self.awakeController = awakeController
        self.lidCloseController = lidCloseController
        self.preferences = preferences
    }

    public func toggle() {
        if state.isActive {
            turnOff()
        } else {
            turnOn()
        }
    }

    public func turnOn() {
        runTransition { [weak self] done in
            self?.performTurnOn(done: done) ?? done()
        }
    }

    public func turnOff() {
        runTransition { [weak self] done in
            self?.performTurnOff(force: false, done: done) ?? done()
        }
    }

    public func shutdownCleanup(done: @escaping () -> Void) {
        shutdownRequested = true
        if isTransitioning {
            pendingShutdownDone = done
        } else {
            performTurnOff(force: true, done: done)
        }
    }

    public func setPreventDisplaySleep(_ enabled: Bool) {
        runTransition { [weak self] done in
            self?.performSetPreventDisplaySleep(enabled, done: done) ?? done()
        }
    }

    public func setPreventLidCloseSleep(_ enabled: Bool) {
        runTransition { [weak self] done in
            self?.performSetPreventLidCloseSleep(enabled, done: done) ?? done()
        }
    }

    public func setPreventDiskSleep(_ enabled: Bool) {
        runTransition { [weak self] done in
            self?.performSetPreventDiskSleep(enabled, done: done) ?? done()
        }
    }

    private func runTransition(_ operation: @escaping (@escaping () -> Void) -> Void) {
        guard !shutdownRequested, !state.isBusy, !isTransitioning else { return }
        isTransitioning = true
        operation { [weak self] in
            guard let self else { return }
            self.isTransitioning = false
            if let shutdownDone = self.pendingShutdownDone {
                self.pendingShutdownDone = nil
                self.performTurnOff(force: true, done: shutdownDone)
            }
        }
    }

    // MARK: - Turn On

    private func performTurnOn(done: @escaping () -> Void) {
        let snapshot = preferences.snapshot()
        state.setBusy(true)
        state.clearError()

        do {
            try awakeController.enable(preventDisplaySleep: snapshot.preventDisplaySleep, preventDiskSleep: snapshot.preventDiskSleep)
        } catch {
            state.recordError(error.localizedDescription)
            done()
            return
        }

        guard snapshot.preventLidCloseSleep else {
            finalizeTurnOn(done: done)
            return
        }

        lidCloseController.enable { [weak self] error in
            guard let self else { done(); return }
            if let error {
                self.awakeController.disable()
                self.lidCloseEngagedThisSession = false
                self.state.recordError(error.localizedDescription)
                done()
                return
            }

            self.lidCloseEngagedThisSession = true

            if self.shutdownRequested {
                self.rollbackForShutdown(done: done)
                return
            }

            self.lidCloseController.status { [weak self] result in
                guard let self else { done(); return }
                switch result {
                case .success(let active) where active:
                    self.finalizeTurnOn(done: done)
                case .success:
                    self.awakeController.disable()
                    self.lidCloseController.disable { _ in }
                    self.lidCloseEngagedThisSession = false
                    self.state.recordError(AppCoordinatorError.lidCloseStatusDidNotBecomeActive.localizedDescription)
                    done()
                case .failure(let error):
                    self.awakeController.disable()
                    self.lidCloseController.disable { _ in }
                    self.lidCloseEngagedThisSession = false
                    self.state.recordError(error.localizedDescription)
                    done()
                }
            }
        }
    }

    private func finalizeTurnOn(done: @escaping () -> Void) {
        if shutdownRequested {
            rollbackForShutdown(done: done)
            return
        }
        state.setActive(true)
        state.setBusy(false)
        done()
    }

    private func rollbackForShutdown(done: @escaping () -> Void) {
        awakeController.disable()
        lidCloseController.disable { [weak self] _ in
            guard let self else { done(); return }
            self.lidCloseEngagedThisSession = false
            self.state.setActive(false)
            self.state.setBusy(false)
            done()
        }
    }

    // MARK: - Turn Off

    private func performTurnOff(force: Bool, done: @escaping () -> Void) {
        guard force || !state.isBusy else { done(); return }
        state.setBusy(true)
        awakeController.disable()

        let needsLidCloseDisable = lidCloseEngagedThisSession
        lidCloseEngagedThisSession = false

        guard needsLidCloseDisable else {
            state.setActive(false)
            state.setBusy(false)
            done()
            return
        }

        lidCloseController.disable { [weak self] error in
            guard let self else { done(); return }
            if let error {
                self.state.setActive(false)
                self.state.setBusy(false)
                self.state.recordError(error.localizedDescription)
                done()
                return
            }

            self.state.setActive(false)
            self.state.setBusy(false)

            self.lidCloseController.status { [weak self] result in
                guard let self else { done(); return }
                if case .success(true) = result {
                    self.state.recordError(AppCoordinatorError.lidCloseStatusRemainedActiveAfterDisable.localizedDescription)
                }
                done()
            }
        }
    }

    // MARK: - Preference Changes

    private func performSetPreventDisplaySleep(_ enabled: Bool, done: @escaping () -> Void) {
        let previous = preferences.preventDisplaySleep
        preferences.preventDisplaySleep = enabled
        guard state.isActive, previous != enabled else { done(); return }

        do {
            try awakeController.setPreventDisplaySleep(enabled)
        } catch {
            preferences.preventDisplaySleep = previous
            state.recordErrorWhileActive(error.localizedDescription)
        }
        done()
    }

    private func performSetPreventDiskSleep(_ enabled: Bool, done: @escaping () -> Void) {
        let previous = preferences.preventDiskSleep
        preferences.preventDiskSleep = enabled
        guard state.isActive, previous != enabled else { done(); return }

        do {
            try awakeController.setPreventDiskSleep(enabled)
        } catch {
            preferences.preventDiskSleep = previous
            state.recordErrorWhileActive(error.localizedDescription)
        }
        done()
    }

    private func performSetPreventLidCloseSleep(_ enabled: Bool, done: @escaping () -> Void) {
        let previous = preferences.preventLidCloseSleep
        preferences.preventLidCloseSleep = enabled
        guard state.isActive, previous != enabled else { done(); return }

        if enabled {
            lidCloseController.enable { [weak self] error in
                guard let self else { done(); return }
                if let error {
                    self.preferences.preventLidCloseSleep = previous
                    self.state.recordErrorWhileActive(error.localizedDescription)
                    done()
                    return
                }

                self.lidCloseEngagedThisSession = true

                self.lidCloseController.status { [weak self] result in
                    guard let self else { done(); return }
                    switch result {
                    case .success(let active) where active:
                        break // success
                    case .success:
                        self.lidCloseController.disable { _ in }
                        self.lidCloseEngagedThisSession = false
                        self.preferences.preventLidCloseSleep = previous
                        self.state.recordErrorWhileActive(
                            AppCoordinatorError.lidCloseStatusDidNotBecomeActive.localizedDescription
                        )
                    case .failure(let error):
                        self.lidCloseController.disable { _ in }
                        self.lidCloseEngagedThisSession = false
                        self.preferences.preventLidCloseSleep = previous
                        self.state.recordErrorWhileActive(error.localizedDescription)
                    }
                    done()
                }
            }
        } else {
            lidCloseController.disable { [weak self] error in
                guard let self else { done(); return }
                if let error {
                    self.state.recordErrorWhileActive(error.localizedDescription)
                    done()
                    return
                }

                self.lidCloseController.status { [weak self] result in
                    guard let self else { done(); return }
                    if case .success(true) = result {
                        self.state.recordErrorWhileActive(
                            AppCoordinatorError.lidCloseStatusRemainedActiveAfterDisable.localizedDescription
                        )
                    }
                    self.lidCloseEngagedThisSession = false
                    done()
                }
            }
        }
    }
}
