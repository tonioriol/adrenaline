import Foundation

public enum LaunchAtLoginStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable
}

public protocol LoginItemServicing: AnyObject {
    var status: LaunchAtLoginStatus { get }
    func register() throws
    func unregister() throws
}

public final class LaunchAgentLoginItemService: LoginItemServicing {
    private let agentLabel: String
    private let appExecutablePath: String?

    public init(
        agentLabel: String = AdrenalineHelperConstants.appBundleIdentifier,
        appExecutablePath: String? = nil
    ) {
        self.agentLabel = agentLabel
        self.appExecutablePath = appExecutablePath
    }

    private var resolvedExecutablePath: String? {
        if let appExecutablePath = appExecutablePath { return appExecutablePath }
        guard let execPath = Bundle.main.executablePath else { return nil }
        let url = URL(fileURLWithPath: execPath)
        let contentsDir = url.deletingLastPathComponent().deletingLastPathComponent()
        let appDir = contentsDir.deletingLastPathComponent()
        guard appDir.pathExtension == "app" else { return nil }
        return appDir.path
    }

    private var launchAgentURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(agentLabel).plist")
    }

    public var status: LaunchAtLoginStatus {
        FileManager.default.fileExists(atPath: launchAgentURL.path) ? .enabled : .disabled
    }

    public func register() throws {
        guard let appPath = resolvedExecutablePath else {
            return
        }

        let plist: NSDictionary = [
            "Label": agentLabel,
            "ProgramArguments": ["/usr/bin/open", appPath],
            "RunAtLoad": true,
        ]

        let dir = launchAgentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        plist.write(to: launchAgentURL, atomically: true)
    }

    public func unregister() throws {
        let path = launchAgentURL.path
        guard FileManager.default.fileExists(atPath: path) else { return }
        try FileManager.default.removeItem(atPath: path)
    }
}

public protocol LaunchAtLoginControlling: AnyObject {
    var isEnabled: Bool { get }
    var status: LaunchAtLoginStatus { get }
    func setEnabled(_ enabled: Bool) throws
}

public final class LaunchAtLoginController: LaunchAtLoginControlling {
    private let service: LoginItemServicing

    public init(service: LoginItemServicing? = nil) {
        self.service = service ?? LaunchAgentLoginItemService()
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
