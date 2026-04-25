import AppKit
import Combine
import CocaineCore

@MainActor
final class MenuBarController: NSObject {
    private let state: AppState
    private let coordinator: AppCoordinator
    private let statusItem: NSStatusItem
    private var cancellables: Set<AnyCancellable> = []

    init(state: AppState, coordinator: AppCoordinator) {
        self.state = state
        self.coordinator = coordinator
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
        let size = NSSize(width: 18, height: 14)

        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            context.saveGState()
            defer { context.restoreGState() }

            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)

            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: .pi / 6)

            let pillRect = CGRect(x: -6.6, y: -3.25, width: 13.2, height: 6.5)
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
                let splitRect = CGRect(
                    x: -0.95,
                    y: pillRect.minY - 1.75,
                    width: 1.9,
                    height: pillRect.height + 3.5
                )
                context.fill(splitRect)
            } else {
                context.setLineWidth(1.6)
                context.addPath(pillPath)
                context.strokePath()

                context.setLineWidth(1.25)
                context.move(to: CGPoint(x: 0, y: pillRect.minY - 0.9))
                context.addLine(to: CGPoint(x: 0, y: pillRect.maxY + 0.9))
                context.strokePath()
            }

            return true
        }

        image.isTemplate = true
        return image
    }

    private var tooltipText: String {
        if state.isBusy { return "Cocaine is changing sleep prevention state" }
        if state.isActive { return "Cocaine is preventing sleep, including lid-close sleep" }
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

        let repairItem = NSMenuItem(title: "Repair/Install Helper", action: #selector(repairHelper), keyEquivalent: "")
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
