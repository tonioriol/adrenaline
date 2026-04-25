import AppKit
import Combine
import CocaineCore

@MainActor
final class MenuBarController: NSObject {
    private let state: AppState
    private let coordinator: AppCoordinator
    private let preferences: PreferencesStore
    private let statusItem: NSStatusItem
    private var cancellables: Set<AnyCancellable> = []

    init(state: AppState, coordinator: AppCoordinator, preferences: PreferencesStore) {
        self.state = state
        self.coordinator = coordinator
        self.preferences = preferences
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureStatusItem()
        bindState()
        render()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func bindState() {
        state.$isActive.receive(on: RunLoop.main).sink { [weak self] _ in self?.render() }.store(in: &cancellables)
        state.$isBusy.receive(on: RunLoop.main).sink { [weak self] _ in self?.render() }.store(in: &cancellables)
        state.$lastErrorMessage.receive(on: RunLoop.main).sink { [weak self] _ in self?.render() }.store(in: &cancellables)
    }

    private func render() {
        guard let button = statusItem.button else { return }
        button.image = statusImage()
        button.toolTip = tooltipText
    }

    private func statusImage() -> NSImage? {
        if state.isBusy {
            return symbolImage(named: "hourglass")
        }

        if state.lastErrorMessage != nil {
            return symbolImage(named: "exclamationmark.triangle")
        }

        return pillImage(filled: state.isActive)
    }

    private func symbolImage(named symbolName: String) -> NSImage? {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Cocaine")
        image?.isTemplate = true
        return image
    }

    private func pillImage(filled: Bool) -> NSImage {
        let pillScale: CGFloat = 1.2
        let size = NSSize(width: 21, height: 17)

        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            context.saveGState()
            defer { context.restoreGState() }

            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)

            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: .pi / 6)

            let pillWidth: CGFloat = 13.2 * pillScale
            let pillHeight: CGFloat = 6.5 * pillScale
            let pillRect = CGRect(
                x: -pillWidth / 2,
                y: -pillHeight / 2,
                width: pillWidth,
                height: pillHeight
            )
            let radius = pillRect.height / 2
            let pillPath = CGPath(
                roundedRect: pillRect,
                cornerWidth: radius,
                cornerHeight: radius,
                transform: nil
            )

            context.setStrokeColor(NSColor.black.cgColor)
            context.setFillColor(NSColor.black.cgColor)

            if filled {
                context.addPath(pillPath)
                context.fillPath()

                context.setBlendMode(.clear)
                let splitWidth: CGFloat = 1.9 * pillScale
                let splitInset: CGFloat = 1.75 * pillScale
                let splitRect = CGRect(
                    x: -splitWidth / 2,
                    y: pillRect.minY - splitInset,
                    width: splitWidth,
                    height: pillRect.height + (splitInset * 2)
                )
                context.fill(splitRect)
            } else {
                context.setLineWidth(1.6)
                context.addPath(pillPath)
                context.strokePath()

                context.setLineWidth(1.25)
                let seamOvershoot: CGFloat = 0.9 * pillScale
                context.move(to: CGPoint(x: 0, y: pillRect.minY - seamOvershoot))
                context.addLine(to: CGPoint(x: 0, y: pillRect.maxY + seamOvershoot))
                context.strokePath()
            }

            return true
        }

        image.isTemplate = true
        return image
    }

    private var tooltipText: String {
        if state.isBusy { return "Cocaine is changing sleep prevention state" }
        if state.isActive {
            return preferences.preventLidCloseSleep
                ? "Cocaine is preventing sleep, including lid-close sleep"
                : "Cocaine is preventing sleep"
        }
        if let error = state.lastErrorMessage { return "Cocaine is off: \(error)" }
        return "Cocaine is off"
    }

    @objc
    private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
            return
        }

        Task { @MainActor in
            await coordinator.toggle()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        if let error = state.lastErrorMessage {
            let errorItem = NSMenuItem(title: "Error: \(error)", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
            menu.addItem(NSMenuItem.separator())
        }

        let aboutItem = NSMenuItem(title: "About Cocaine", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeCheckboxItem(
            title: "Prevent display sleep",
            isOn: preferences.preventDisplaySleep,
            action: #selector(togglePreventDisplaySleep)
        ))

        let lidCloseTitle = preferences.preventLidCloseSleep
            ? "⚠ Prevent sleep with lid closed"
            : "Prevent sleep with lid closed"
        menu.addItem(makeCheckboxItem(
            title: lidCloseTitle,
            isOn: preferences.preventLidCloseSleep,
            action: #selector(togglePreventLidCloseSleep)
        ))

        let lockItem = makeCheckboxItem(
            title: "    Lock screen when lid closes",
            isOn: preferences.lockScreenOnLidClose,
            action: #selector(toggleLockScreenOnLidClose)
        )
        lockItem.isEnabled = preferences.preventLidCloseSleep
        menu.addItem(lockItem)

        menu.addItem(makeCheckboxItem(
            title: "Play lid event sounds",
            isOn: preferences.playLidEventSounds,
            action: #selector(togglePlayLidEventSounds)
        ))

        menu.addItem(NSMenuItem.separator())

        let repairItem = NSMenuItem(title: "Repair / Install Helper", action: #selector(repairHelper), keyEquivalent: "")
        repairItem.target = self
        repairItem.isEnabled = state.lastErrorMessage != nil
        menu.addItem(repairItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func makeCheckboxItem(title: String, isOn: Bool, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = isOn ? .on : .off
        return item
    }

    @objc
    private func togglePreventDisplaySleep() {
        let newValue = !preferences.preventDisplaySleep
        Task { @MainActor in
            await coordinator.setPreventDisplaySleep(newValue)
        }
    }

    @objc
    private func togglePreventLidCloseSleep() {
        let newValue = !preferences.preventLidCloseSleep
        if newValue && !preferences.lidClosePreventionConfirmed {
            guard confirmLidClosePreventionEnable() else { return }
            preferences.lidClosePreventionConfirmed = true
        }
        if !newValue {
            preferences.lidClosePreventionConfirmed = false
        }
        Task { @MainActor in
            await coordinator.setPreventLidCloseSleep(newValue)
        }
    }

    private func confirmLidClosePreventionEnable() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Prevent sleep with lid closed?"
        alert.informativeText = "Preventing lid-close sleep can leave a closed MacBook running. " +
            "Don't put it in a bag while this is enabled — it may overheat."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Enable")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    @objc
    private func toggleLockScreenOnLidClose() {
        preferences.lockScreenOnLidClose.toggle()
    }

    @objc
    private func togglePlayLidEventSounds() {
        preferences.playLidEventSounds.toggle()
    }

    @objc
    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: "Personal keep-awake utility inspired by Caffeine and Fermata."),
        ])
    }

    @objc
    private func repairHelper() {
        Task { @MainActor in
            await coordinator.turnOn()
        }
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}
