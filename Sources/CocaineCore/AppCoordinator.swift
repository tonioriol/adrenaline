import Foundation

public protocol AwakeControlling: AnyObject {
    func enable() throws
    func enable(preventDisplaySleep: Bool) throws
    func setPreventDisplaySleep(_ enabled: Bool) throws
    func disable()
}

public protocol LidCloseControlling: AnyObject {
    func enable() async throws
    func disable() async throws
    func status() async throws -> Bool
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

@MainActor
public final class AppCoordinator {
    private let state: AppState
    private let awakeController: AwakeControlling
    private let lidCloseController: LidCloseControlling
    private let preferences: PreferencesProviding
    private var shutdownRequested = false
    private var currentTransitionTask: Task<Void, Never>?
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

    public convenience init(
        state: AppState,
        awakeController: AwakeControlling,
        lidCloseController: LidCloseControlling
    ) {
        self.init(
            state: state,
            awakeController: awakeController,
            lidCloseController: lidCloseController,
            preferences: PreferencesStore()
        )
    }

    public func toggle() async {
        if state.isActive {
            await turnOff()
        } else {
            await turnOn()
        }
    }

    public func turnOn() async {
        await runTransition {
            await self.performTurnOn()
        }
    }

    public func turnOff() async {
        await runTransition {
            await self.performTurnOff(force: false)
        }
    }

    public func shutdownCleanup() async {
        shutdownRequested = true
        let inFlightTransition = currentTransitionTask
        await inFlightTransition?.value
        await performTurnOff(force: true)
    }

    public func setPreventDisplaySleep(_ enabled: Bool) async {
        await runTransition {
            await self.performSetPreventDisplaySleep(enabled)
        }
    }

    public func setPreventLidCloseSleep(_ enabled: Bool) async {
        await runTransition {
            await self.performSetPreventLidCloseSleep(enabled)
        }
    }

    private func runTransition(_ operation: @escaping @MainActor () async -> Void) async {
        guard !shutdownRequested, !state.isBusy, currentTransitionTask == nil else { return }

        let task = Task { @MainActor in
            await operation()
        }
        currentTransitionTask = task
        await task.value
        currentTransitionTask = nil
    }

    private func performTurnOn() async {
        let snapshot = preferences.snapshot()
        state.setBusy(true)
        state.clearError()

        do {
            try awakeController.enable(preventDisplaySleep: snapshot.preventDisplaySleep)

            if snapshot.preventLidCloseSleep {
                try await lidCloseController.enable()
                lidCloseEngagedThisSession = true

                if shutdownRequested {
                    await rollbackForShutdown()
                    return
                }

                guard try await lidCloseController.status() else {
                    throw AppCoordinatorError.lidCloseStatusDidNotBecomeActive
                }
            }

            if shutdownRequested {
                await rollbackForShutdown()
                return
            }

            state.setActive(true)
            state.setBusy(false)
        } catch {
            awakeController.disable()
            try? await lidCloseController.disable()
            lidCloseEngagedThisSession = false
            state.recordError(error.localizedDescription)
        }
    }

    private func rollbackForShutdown() async {
        awakeController.disable()
        try? await lidCloseController.disable()
        lidCloseEngagedThisSession = false
        state.setActive(false)
        state.setBusy(false)
    }

    private func performTurnOff(force: Bool) async {
        guard force || !state.isBusy else { return }
        state.setBusy(true)
        awakeController.disable()

        let needsLidCloseDisable = lidCloseEngagedThisSession
        lidCloseEngagedThisSession = false

        guard needsLidCloseDisable else {
            state.setActive(false)
            state.setBusy(false)
            return
        }

        do {
            try await lidCloseController.disable()
            state.setActive(false)
            state.setBusy(false)

            if try await lidCloseController.status() {
                throw AppCoordinatorError.lidCloseStatusRemainedActiveAfterDisable
            }
        } catch {
            state.setActive(false)
            state.setBusy(false)
            state.recordError(error.localizedDescription)
        }
    }

    private func performSetPreventDisplaySleep(_ enabled: Bool) async {
        let previous = preferences.preventDisplaySleep
        preferences.preventDisplaySleep = enabled
        guard state.isActive, previous != enabled else { return }

        do {
            try awakeController.setPreventDisplaySleep(enabled)
        } catch {
            preferences.preventDisplaySleep = previous
            state.recordErrorWhileActive(error.localizedDescription)
        }
    }

    private func performSetPreventLidCloseSleep(_ enabled: Bool) async {
        let previous = preferences.preventLidCloseSleep
        preferences.preventLidCloseSleep = enabled
        guard state.isActive, previous != enabled else { return }

        if enabled {
            do {
                try await lidCloseController.enable()
                lidCloseEngagedThisSession = true
                guard try await lidCloseController.status() else {
                    throw AppCoordinatorError.lidCloseStatusDidNotBecomeActive
                }
            } catch {
                try? await lidCloseController.disable()
                lidCloseEngagedThisSession = false
                preferences.preventLidCloseSleep = previous
                state.recordErrorWhileActive(error.localizedDescription)
            }
        } else {
            do {
                try await lidCloseController.disable()
                lidCloseEngagedThisSession = false
            } catch {
                lidCloseEngagedThisSession = false
                state.recordError(error.localizedDescription)
            }
        }
    }
}
