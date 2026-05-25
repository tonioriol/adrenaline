import Foundation

public enum HelperState: Equatable {
    case unknown
    case notInstalled
    case installing
    case ready(version: Int)
    case failed(message: String)
}

public extension Notification.Name {
    static let appStateActiveDidChange = Notification.Name("Adrenaline.appStateActiveDidChange")
    static let appStateBusyDidChange = Notification.Name("Adrenaline.appStateBusyDidChange")
    static let appStateErrorDidChange = Notification.Name("Adrenaline.appStateErrorDidChange")
    static let appStateHelperDidChange = Notification.Name("Adrenaline.appStateHelperDidChange")
}

public final class AppState {
    public private(set) var isActive: Bool {
        didSet {
            guard isActive != oldValue else { return }
            NotificationCenter.default.post(name: .appStateActiveDidChange, object: self)
        }
    }

    public private(set) var isBusy: Bool {
        didSet {
            guard isBusy != oldValue else { return }
            NotificationCenter.default.post(name: .appStateBusyDidChange, object: self)
        }
    }

    public private(set) var helperState: HelperState {
        didSet {
            guard helperState != oldValue else { return }
            NotificationCenter.default.post(name: .appStateHelperDidChange, object: self)
        }
    }

    public private(set) var lastErrorMessage: String? {
        didSet {
            guard lastErrorMessage != oldValue else { return }
            NotificationCenter.default.post(name: .appStateErrorDidChange, object: self)
        }
    }

    public init(
        isActive: Bool = false,
        isBusy: Bool = false,
        helperState: HelperState = .unknown,
        lastErrorMessage: String? = nil
    ) {
        self.isActive = isActive
        self.isBusy = isBusy
        self.helperState = helperState
        self.lastErrorMessage = lastErrorMessage
    }

    public func setBusy(_ value: Bool) {
        isBusy = value
    }

    public func setActive(_ value: Bool) {
        isActive = value
        if value {
            lastErrorMessage = nil
            if case .failed = helperState {
                helperState = .unknown
            }
        }
    }

    public func setHelperState(_ value: HelperState) {
        helperState = value
        if case let .failed(message) = value {
            isActive = false
            isBusy = false
            lastErrorMessage = message
        }
    }

    public func recordError(_ message: String) {
        isActive = false
        isBusy = false
        lastErrorMessage = message
        helperState = .failed(message: message)
    }

    public func recordErrorWhileActive(_ message: String) {
        isBusy = false
        lastErrorMessage = message
        helperState = .failed(message: message)
    }

    public func clearError() {
        lastErrorMessage = nil
        if case .failed = helperState {
            helperState = .unknown
        }
    }
}
