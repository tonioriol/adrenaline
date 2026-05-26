import AppKit
import AdrenalineCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var preferences: PreferencesStore?
    private var menuBarController: MenuBarController?
    private var coordinator: AppCoordinator?
    private var lidEventSoundController: LidEventSoundController?
    private var lidCloseLockResponder: LidCloseLockResponder?
    private var updater: SparkleUpdaterController?
    private var activeStateObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let preferences = PreferencesStore()
        let state = AppState()
        let awake = AwakeController()
        let lidClose = LidCloseController()
        let coordinator = AppCoordinator(
            state: state,
            awakeController: awake,
            lidCloseController: lidClose,
            preferences: preferences
        )
        let lidStateMonitor = LidStateMonitor()
        let soundPlayer = SystemSoundPlayer()
        let screenLocker = LoginFrameworkScreenLocker()
        let lockPolicyReader = MacOSLockPolicyReader()

        let lidEventSoundController = LidEventSoundController(
            state: state,
            monitor: lidStateMonitor,
            soundPlayer: soundPlayer,
            preferences: preferences
        )
        let lidCloseLockResponder = LidCloseLockResponder(
            state: state,
            monitor: lidStateMonitor,
            screenLocker: screenLocker,
            preferences: preferences,
            policyReader: lockPolicyReader
        )

        let updater = SparkleUpdaterController()
        let diskTypeDetector = DiskTypeDetector()

        self.preferences = preferences
        self.coordinator = coordinator
        self.lidEventSoundController = lidEventSoundController
        self.lidCloseLockResponder = lidCloseLockResponder
        self.updater = updater
        self.menuBarController = MenuBarController(
            state: state,
            coordinator: coordinator,
            preferences: preferences,
            launchAtLoginController: LaunchAtLoginController(),
            updater: updater,
            diskTypeDetector: diskTypeDetector
        )

        activeStateObserver = NotificationCenter.default.addObserver(
            forName: .appStateActiveDidChange,
            object: state,
            queue: .main
        ) { [weak preferences, weak state] _ in
            if let isActive = state?.isActive {
                preferences?.wasActive = isActive
            }
        }

        if preferences.wasActive {
            coordinator.turnOn()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let coordinator else { return .terminateNow }
        coordinator.shutdownCleanup {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
