import Combine
import Foundation

public enum HelperState: Equatable, Sendable {
    case unknown
    case notInstalled
    case installing
    case ready(version: Int)
    case failed(message: String)
}

@MainActor
public final class AppState: ObservableObject {
    @Published public private(set) var isActive: Bool
    @Published public private(set) var isBusy: Bool
    @Published public private(set) var helperState: HelperState
    @Published public private(set) var lastErrorMessage: String?

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
