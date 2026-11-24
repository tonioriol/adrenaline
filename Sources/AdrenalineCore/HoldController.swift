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
        if changed { notify() }
        reconcile()
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
        if completedTarget != wantsActive { reconcile() }
    }

    private func reconcile() {
        let target = wantsActive
        guard requestedActive == nil, target != state.isActive else { return }
        requestedActive = target
        if !(target ? coordinator.turnOn() : coordinator.turnOff()) {
            // Busy with an unrelated operation; its completion reconciles again.
            requestedActive = nil
        }
    }
}
