import Foundation

public protocol AwakeControlling: AnyObject {
    func enable() throws
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
    private var shutdownRequested = false
    private var currentTransitionTask: Task<Void, Never>?

    public init(
        state: AppState,
        awakeController: AwakeControlling,
        lidCloseController: LidCloseControlling
    ) {
        self.state = state
        self.awakeController = awakeController
        self.lidCloseController = lidCloseController
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

    private func performTurnOn() async {
        state.setBusy(true)
        state.clearError()

        do {
            try awakeController.enable()
            try await lidCloseController.enable()

            if shutdownRequested {
                await rollbackForShutdown()
                return
            }

            guard try await lidCloseController.status() else {
                throw AppCoordinatorError.lidCloseStatusDidNotBecomeActive
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
            state.recordError(error.localizedDescription)
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

    private func runTransition(_ operation: @escaping @MainActor () async -> Void) async {
        guard !shutdownRequested, !state.isBusy, currentTransitionTask == nil else { return }

        let task = Task { @MainActor in
            await operation()
        }
        currentTransitionTask = task
        await task.value
        currentTransitionTask = nil
    }

    private func rollbackForShutdown() async {
        awakeController.disable()
        try? await lidCloseController.disable()
        state.setActive(false)
        state.setBusy(false)
    }

    private func performTurnOff(force: Bool) async {
        guard force || !state.isBusy else { return }
        state.setBusy(true)
        awakeController.disable()

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
}
