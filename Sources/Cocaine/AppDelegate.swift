import AppKit
import CocaineCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var coordinator: AppCoordinator?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState()
        let awake = AwakeController()
        let lidClose = LidCloseController()
        let coordinator = AppCoordinator(state: state, awakeController: awake, lidCloseController: lidClose)

        self.coordinator = coordinator
        self.menuBarController = MenuBarController(state: state, coordinator: coordinator)
    }

    @MainActor
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let coordinator else { return .terminateNow }
        Task { @MainActor in
            await coordinator.turnOff()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
