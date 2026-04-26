import Foundation
import ServiceManagement

public enum LaunchAtLoginStatus: Equatable, Sendable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    init(serviceManagementStatus: SMAppService.Status) {
        switch serviceManagementStatus {
        case .enabled:
            self = .enabled
        case .notRegistered:
            self = .disabled
        case .requiresApproval:
            self = .requiresApproval
        case .notFound:
            self = .unavailable
        @unknown default:
            self = .unavailable
        }
    }
}

@MainActor
public protocol LoginItemServicing: AnyObject {
    var status: LaunchAtLoginStatus { get }
    func register() throws
    func unregister() throws
}

@MainActor
public final class MainAppLoginItemService: LoginItemServicing {
    public init() {}

    public var status: LaunchAtLoginStatus {
        LaunchAtLoginStatus(serviceManagementStatus: SMAppService.mainApp.status)
    }

    public func register() throws {
        try SMAppService.mainApp.register()
    }

    public func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

@MainActor
public protocol LaunchAtLoginControlling: AnyObject {
    var isEnabled: Bool { get }
    var status: LaunchAtLoginStatus { get }
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
public final class LaunchAtLoginController: LaunchAtLoginControlling {
    private let service: LoginItemServicing

    public init(service: LoginItemServicing? = nil) {
        self.service = service ?? MainAppLoginItemService()
    }

    public var isEnabled: Bool {
        service.status == .enabled
    }

    public var status: LaunchAtLoginStatus {
        service.status
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard service.status != .enabled else { return }
            try service.register()
            return
        }

        switch service.status {
        case .enabled, .requiresApproval:
            try service.unregister()
        case .disabled, .unavailable:
            return
        }
    }
}
