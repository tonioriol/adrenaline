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
        guard !state.isBusy else { return }
        state.setBusy(true)
        state.clearError()

        do {
            try awakeController.enable()
            try await lidCloseController.enable()

            guard try await lidCloseController.status() else {
                throw AppCoordinatorError.lidCloseStatusDidNotBecomeActive
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
        guard !state.isBusy else { return }
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
