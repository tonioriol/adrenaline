import Foundation

public protocol HoldActivating: AnyObject {
    /// Returns false when the request was dropped because another transition is in flight.
    @discardableResult func turnOn() -> Bool
    @discardableResult func turnOff() -> Bool
    /// Re-applies the current preferences while active; a no-op when they are already in force.
    @discardableResult func reapply() -> Bool
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

public enum ActivationMode: String, CaseIterable {
    case off, auto, on
}

public extension Notification.Name {
    static let holdStateDidChange = Notification.Name("Adrenaline.holdStateDidChange")
}

/// Applies the selected activation policy. Must be used from the main queue.
public final class HoldController {
    private let state: AppState
    private let coordinator: HoldActivating
    private var nextID = 1
    private var requestedActive: Bool?
    /// The mode changed while active, so the new mode's preset still has to be applied.
    private var reapplyPending = false

    public private(set) var mode: ActivationMode
    public private(set) var holds: [Hold] = []
    public var isAutoHeld: Bool { mode == .auto && !holds.isEmpty }
    public var isHoldDriven: Bool { isAutoHeld && (state.isActive || requestedActive == true) }

    public init(state: AppState, coordinator: HoldActivating, mode: ActivationMode) {
        self.state = state
        self.coordinator = coordinator
        self.mode = mode
        coordinator.onTransitionEnd = { [weak self] in self?.transitionEnded() }
        reconcile()
    }

    public func setMode(_ mode: ActivationMode) {
        let changed = self.mode != mode
        self.mode = mode
        if mode == .off { holds.removeAll() }
        if changed {
            if wantsActive { reapplyPending = true }
            notify()
        }
        reconcile()
    }

    /// The next mode in the click cycle: Off → Auto → On → Off.
    public var nextMode: ActivationMode {
        let all = ActivationMode.allCases
        return all[(all.firstIndex(of: mode)! + 1) % all.count]
    }

    @discardableResult
    public func acquire(reason: String?, pid: Int32?, replacing previousID: Int? = nil) -> Int? {
        guard mode != .off else { return nil }
        if let previousID { holds.removeAll { $0.id == previousID } }
        let id = nextID
        nextID += 1
        holds.append(Hold(id: id, reason: reason, pid: pid))
        notify()
        reconcile()
        return id
    }

    public func release(_ id: Int) {
        guard let index = holds.firstIndex(where: { $0.id == id }) else { return }
        holds.remove(at: index)
        notify()
        reconcile()
    }

    private var wantsActive: Bool { mode == .on || isAutoHeld }

    private func notify() {
        NotificationCenter.default.post(name: .holdStateDidChange, object: self)
    }

    private func transitionEnded() {
        let completedTarget = requestedActive
        requestedActive = nil
        // A failed transition must not immediately retry itself. Still apply a
        // different target if the mode or holds changed mid-transition.
        if completedTarget != wantsActive || reapplyPending { reconcile() }
    }

    private func reconcile() {
        guard requestedActive == nil else { return }
        let target = wantsActive
        // Cleared before the call, which may finish synchronously and reconcile again.
        // Turning on reads the current preset and turning off needs none, so either settles it.
        let pending = reapplyPending
        reapplyPending = false
        if target != state.isActive {
            requestedActive = target
            if !(target ? coordinator.turnOn() : coordinator.turnOff()) {
                // Busy with an unrelated operation; its completion reconciles again.
                requestedActive = nil
                reapplyPending = pending
            }
        } else if pending, target, !coordinator.reapply() {
            reapplyPending = true
        }
    }
}
