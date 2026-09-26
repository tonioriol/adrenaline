import Foundation

public protocol HoldActivating: AnyObject {
    /// Returns false when the request was dropped because another transition is in flight.
    @discardableResult func turnOn() -> Bool
    @discardableResult func turnOff() -> Bool
    var onTransitionEnd: (() -> Void)? { get set }
}

public struct Hold: Equatable {
    public let id: Int
    public var reason: String?
    public var pid: Int32?

    public init(id: Int, reason: String?, pid: Int32?) {
        self.id = id
        self.reason = reason
        self.pid = pid
    }
}

/// Keeps Adrenaline on while at least one external client holds it.
///
/// Holds only switch Adrenaline off again if holds switched it on. If the user
/// already had it on, releasing the last hold leaves it on. If the user turns it
/// off while holds exist, or turning on fails, holds yield until a new hold arrives.
/// Must be used from the main queue.
public final class HoldController {
    private let state: AppState
    private let coordinator: HoldActivating
    private var observer: NSObjectProtocol?
    private var nextID = 1
    private var awaitingOwnTurnOn = false
    private var yieldedUntilNextHold = false

    public private(set) var holds: [Hold] = []
    /// True while the current activation was started by holds rather than the user.
    public private(set) var ownsActivation = false

    public var isHoldDriven: Bool { ownsActivation || awaitingOwnTurnOn }

    public init(state: AppState, coordinator: HoldActivating) {
        self.state = state
        self.coordinator = coordinator
        coordinator.onTransitionEnd = { [weak self] in self?.transitionEnded() }
        observer = NotificationCenter.default.addObserver(
            forName: .appStateActiveDidChange,
            object: state,
            queue: nil
        ) { [weak self] _ in
            self?.activeChanged()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    @discardableResult
    public func acquire(reason: String?, pid: Int32?) -> Int {
        let id = nextID
        nextID += 1
        holds.append(Hold(id: id, reason: reason, pid: pid))
        yieldedUntilNextHold = false
        reconcile()
        return id
    }

    public func release(_ id: Int) {
        let count = holds.count
        holds.removeAll { $0.id == id }
        guard holds.count != count else { return }
        reconcile()
    }

    private func transitionEnded() {
        if awaitingOwnTurnOn {
            awaitingOwnTurnOn = false
            ownsActivation = state.isActive
            if !state.isActive { yieldedUntilNextHold = true }
        }
        reconcile()
    }

    private func activeChanged() {
        // The user (or an error) switched Adrenaline off under our holds.
        if !state.isActive, ownsActivation {
            ownsActivation = false
            if !holds.isEmpty { yieldedUntilNextHold = true }
        }
    }

    private func reconcile() {
        if !holds.isEmpty {
            guard !state.isActive, !yieldedUntilNextHold, !awaitingOwnTurnOn else { return }
            awaitingOwnTurnOn = true
            if !coordinator.turnOn() {
                // Busy; retried when the running transition ends.
                awaitingOwnTurnOn = false
            }
        } else if ownsActivation, state.isActive {
            ownsActivation = false
            if !coordinator.turnOff() {
                ownsActivation = true
            }
        }
    }
}
