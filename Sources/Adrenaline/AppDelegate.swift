import AppKit
import AdrenalineCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var preferences: PreferencesStore?
    private var menuBarController: MenuBarController?
    private var coordinator: AppCoordinator?
    private var lidEventSoundController: LidEventSoundController?
    private var lidCloseLockResponder: LidCloseLockResponder?
    private var stayUnlockedController: StayUnlockedController?
    private var updater: SparkleUpdaterController?
    private var activeStateObserver: NSObjectProtocol?
    private var holdController: HoldController?
    private var holdSocketServer: HoldSocketServer?

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
        let soundPlayer = SystemSoundPlayer(preferences: preferences)
        let screenLocker = LoginFrameworkScreenLocker()
        let lockPolicyReader = MacOSLockPolicyReader()

        let lidEventSoundController = LidEventSoundController(
            state: state,
            monitor: lidStateMonitor,
            soundPlayer: soundPlayer,
            preferences: preferences
        )
        let stayUnlockedController = StayUnlockedController(
            state: state,
            preferences: preferences,
            setting: SysadminctlScreenLockSetting(),
            passwordStore: KeychainPasswordStore(),
            requestPassword: LoginPasswordPrompt.run
        )
        let lidCloseLockResponder = LidCloseLockResponder(
            state: state,
            monitor: lidStateMonitor,
            screenLocker: screenLocker,
            preferences: preferences,
            policyReader: lockPolicyReader,
            awakeController: awake,
            isStayingUnlocked: { [weak stayUnlockedController] in stayUnlockedController?.isEngaged ?? false },
            displaySleeper: PmsetDisplaySleeper()
        )

        let updater = SparkleUpdaterController()
        let diskTypeDetector = DiskTypeDetector()

        self.preferences = preferences
        self.coordinator = coordinator
        self.lidEventSoundController = lidEventSoundController
        self.lidCloseLockResponder = lidCloseLockResponder
        self.stayUnlockedController = stayUnlockedController
        self.updater = updater
        self.menuBarController = MenuBarController(
            state: state,
            coordinator: coordinator,
            preferences: preferences,
            launchAtLoginController: LaunchAtLoginController(),
            updater: updater,
            diskTypeDetector: diskTypeDetector
        )

        let holdController = HoldController(state: state, coordinator: coordinator)
        let holdSocketServer = HoldSocketServer(holds: holdController, state: state)
        do {
            try holdSocketServer.start()
        } catch {
            NSLog("Adrenaline: hold socket unavailable: \(error.localizedDescription)")
        }
        self.holdController = holdController
        self.holdSocketServer = holdSocketServer

        activeStateObserver = NotificationCenter.default.addObserver(
            forName: .appStateActiveDidChange,
            object: state,
            queue: .main
        ) { [weak preferences, weak state, weak holdController] _ in
            guard let isActive = state?.isActive else { return }
            // Don't remember activations made on behalf of external holds.
            if isActive, holdController?.isHoldDriven == true { return }
            preferences?.wasActive = isActive
        }

        if preferences.wasActive {
            coordinator.turnOn()
        } else {
            // Puts back a lock setting left changed by a crash.
            stayUnlockedController.apply()
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
