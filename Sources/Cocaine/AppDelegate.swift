import AppKit
import CocaineCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var coordinator: AppCoordinator?
    private var lidEventSoundController: LidEventSoundController?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState()
        let awake = AwakeController()
        let lidClose = LidCloseController()
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lidClose)
        let lidStateMonitor = LidStateMonitor()
        let soundPlayer = SystemSoundPlayer()

        self.coordinator = coordinator
        self.lidEventSoundController = LidEventSoundController(
            state: state,
            monitor: lidStateMonitor,
            soundPlayer: soundPlayer
        )
        self.menuBarController = MenuBarController(state: state, coordinator: coordinator)
    }

    @MainActor
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let coordinator else { return .terminateNow }
        Task { @MainActor in
            await coordinator.shutdownCleanup()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
