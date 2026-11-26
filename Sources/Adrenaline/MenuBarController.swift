import AppKit
import AdrenalineCore

final class MenuBarController: NSObject {
    private enum PreferenceRowID: Hashable {
        case preventDisplaySleep
        case preventDiskSleep
        case preventLidCloseSleep
        case playLidEventSounds
        case overrideSystemVolumeForLidEventSounds
        case stayUnlockedWithLidClosed
        case launchAtLogin

        init?(_ rowID: PreferenceMenuRowID) {
            switch rowID {
            case .preventDisplaySleep:
                self = .preventDisplaySleep
            case .preventDiskSleep:
                self = .preventDiskSleep
            case .preventLidCloseSleep:
                self = .preventLidCloseSleep
            case .playLidEventSounds:
                self = .playLidEventSounds
            case .overrideSystemVolumeForLidEventSounds:
                self = .overrideSystemVolumeForLidEventSounds
            case .stayUnlockedWithLidClosed:
                self = .stayUnlockedWithLidClosed
            }
        }
    }

    private let state: AppState
    private let coordinator: AppCoordinator
    private let holds: HoldController
    private weak var visibleMenu: NSMenu?
    private var holdItems: [NSMenuItem] = []
    private let holdHeading = NSMenuItem(title: "Held by", action: nil, keyEquivalent: "")
    private let presetHeading = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var modeRows: [ActivationMode: CheckboxMenuItemView] = [:]
    private let preferences: PreferencesStore
    private let launchAtLoginController: LaunchAtLoginControlling
    private let updater: Updating
    private let diskTypeDetector: DiskTypeDetecting
    private var aboutWindowController: AboutWindowController?
    private let statusItem: NSStatusItem
    private var observers: [NSObjectProtocol] = []
    private var visibleRows: [PreferenceRowID: CheckboxMenuItemView] = [:]
    private var launchAtLoginErrorMessage: String?

    init(
        state: AppState,
        coordinator: AppCoordinator,
        preferences: PreferencesStore,
        holds: HoldController,
        launchAtLoginController: LaunchAtLoginControlling,
        updater: Updating,
        diskTypeDetector: DiskTypeDetecting
    ) {
        self.state = state
        self.coordinator = coordinator
        self.preferences = preferences
        self.holds = holds
        self.launchAtLoginController = launchAtLoginController
        self.updater = updater
        self.diskTypeDetector = diskTypeDetector
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
        button.sendAction(on: [.leftMouseDown, .rightMouseUp])
    }

    private func bindState() {
        let center = NotificationCenter.default

        observers.append(
            center.addObserver(forName: .holdStateDidChange, object: holds, queue: .main) { [weak self] _ in
                self?.render()
                self?.refreshHoldItems()
                self?.refreshModeRows()
            }
        )

        observers.append(
            center.addObserver(forName: .appStateActiveDidChange, object: state, queue: .main) { [weak self] _ in
                self?.render()
            }
        )
        observers.append(
            center.addObserver(forName: .appStateBusyDidChange, object: state, queue: .main) { [weak self] _ in
                self?.render()
            }
        )
        observers.append(
            center.addObserver(forName: .appStateErrorDidChange, object: state, queue: .main) { [weak self] _ in
                self?.render()
            }
        )
        observers.append(
            center.addObserver(forName: .preferencesPreventLidCloseSleepDidChange, object: preferences, queue: .main) { [weak self] _ in
                self?.render()
                self?.refreshVisibleRows()
            }
        )
        observers.append(
            center.addObserver(forName: .preferencesPreventDiskSleepDidChange, object: preferences, queue: .main) { [weak self] _ in
                self?.refreshVisibleRows()
            }
        )
        observers.append(
            center.addObserver(forName: .preferencesPlayLidEventSoundsDidChange, object: preferences, queue: .main) { [weak self] _ in
                self?.refreshVisibleRows()
            }
        )
        observers.append(
            center.addObserver(forName: .preferencesStayUnlockedWithLidClosedDidChange, object: preferences, queue: .main) { [weak self] _ in
                self?.refreshVisibleRows()
            }
        )
        observers.append(
            center.addObserver(forName: .preferencesOverrideSystemVolumeForLidEventSoundsDidChange, object: preferences, queue: .main) { [weak self] _ in
                self?.refreshVisibleRows()
            }
        )
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
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

        let fill: StatusPill.Fill
        switch holds.mode {
        case .off: fill = .none
        case .auto: fill = .half
        case .on: fill = .full
        }
        return StatusPill.image(fill: fill, badged: holds.isAutoHeld)
    }

    private func symbolImage(named symbolName: String) -> NSImage? {
        if #available(macOS 11.0, *) {
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Adrenaline")
            image?.isTemplate = true
            return image
        }

        switch symbolName {
        case "hourglass":
            return legacySymbolImage(text: "⌛")
        case "exclamationmark.triangle":
            return legacySymbolImage(text: "⚠")
        default:
            return nil
        }
    }

    private func legacySymbolImage(text: String) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.black,
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedText.size()
        let rect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        attributedText.draw(in: rect)

        image.unlockFocus()
        return image
    }

    private var tooltipText: String {
        let status: String
        if state.isBusy {
            status = "Changing sleep prevention state"
        } else if let error = state.lastErrorMessage {
            status = error
        } else if state.isActive {
            status = preferences.preventLidCloseSleep
                ? "Preventing sleep, including lid-close sleep"
                : "Preventing sleep"
        } else {
            status = holds.mode == .auto ? "Waiting for a hold" : "Not preventing sleep"
        }
        var lines = ["Adrenaline — \(holds.mode.rawValue.capitalized)", status]
        if !holds.holds.isEmpty {
            lines.append("Held by: " + holds.holds.map { holdLabel($0, includePID: false) }.joined(separator: ", "))
        }
        lines.append("Click for \(holds.nextMode.rawValue.capitalized) · right-click or hold for the menu")
        return lines.joined(separator: "\n")
    }

    private func holdLabel(_ hold: Hold, includePID: Bool) -> String {
        let reason = hold.reason?.split(whereSeparator: \.isWhitespace).joined(separator: " ") ?? ""
        guard !reason.isEmpty else { return hold.pid.map { "PID \($0)" } ?? "Unknown program" }
        if includePID, let pid = hold.pid { return "\(reason) (PID \(pid))" }
        return reason
    }

    @objc
    private func statusItemClicked(_ sender: NSStatusBarButton) {
        // A click cycles the mode; a long press, right-click or control-click opens the menu.
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.control) || isLongPress() {
            showMenu()
            return
        }
        setMode(holds.nextMode)
    }

    /// Waits for the left mouse button to be released. Returns true if it is
    /// still held after `longPressDuration`, so the menu opens under the held
    /// button and releasing over a row picks it.
    private func isLongPress() -> Bool {
        let longPressDuration: TimeInterval = 0.5
        let mouseUp = NSApp.nextEvent(
            matching: .leftMouseUp,
            until: Date(timeIntervalSinceNow: longPressDuration),
            inMode: .eventTracking,
            dequeue: true
        )
        return mouseUp == nil
    }

    private func showMenu() {
        let menu = NSMenu()
        visibleRows = [:]

        if let error = state.lastErrorMessage {
            let errorItem = NSMenuItem(title: "Error: \(error)", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
            menu.addItem(NSMenuItem.separator())
        }

        if let launchAtLoginErrorMessage {
            let errorItem = NSMenuItem(title: "Login item error: \(launchAtLoginErrorMessage)", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
            menu.addItem(NSMenuItem.separator())
        }

        // View rows, so picking a mode leaves the menu open.
        modeRows = [:]
        for mode in ActivationMode.allCases {
            let item = NSMenuItem()
            let row = CheckboxMenuItemView(title: mode.rawValue.capitalized, isOn: mode == holds.mode, radio: true)
            row.onToggle = { [weak self] in self?.setMode(mode) }
            item.view = row
            menu.addItem(item)
            modeRows[mode] = row
        }

        menu.addItem(NSMenuItem.separator())
        holdHeading.isEnabled = false
        menu.addItem(holdHeading)
        visibleMenu = menu
        refreshHoldItems()

        let aboutItem = NSMenuItem(title: "About Adrenaline", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        presetHeading.title = presetHeadingTitle
        presetHeading.isEnabled = false
        menu.addItem(presetHeading)

        for row in PreferenceMenuRows.rows(for: preferences.snapshot(), showDiskSleep: diskTypeDetector.hasNonSSDDrive) {
            guard let id = PreferenceRowID(row.id) else { continue }
            addCheckboxRow(
                to: menu,
                id: id,
                title: row.title,
                isOn: row.isOn,
                isEnabled: row.isEnabled,
                isChild: row.isChild
            ) { [weak self] in
                self?.togglePreference(row.id)
            }
        }

        addCheckboxRow(
            to: menu,
            id: .launchAtLogin,
            title: "Launch at login",
            isOn: launchAtLoginController.isEnabled,
            isEnabled: true
        ) { [weak self] in
            self?.toggleLaunchAtLogin()
        }

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
        menu.removeItem(holdHeading)
        menu.removeItem(presetHeading)
        visibleMenu = nil
        holdItems = []
        visibleRows = [:]
        modeRows = [:]
    }

    private var presetHeadingTitle: String {
        "When \(preferences.preset.rawValue.capitalized)"
    }

    private func refreshModeRows() {
        for (mode, row) in modeRows {
            row.update(title: mode.rawValue.capitalized, isOn: mode == holds.mode, isEnabled: true)
        }
        presetHeading.title = presetHeadingTitle
    }

    private func refreshHoldItems() {
        guard let menu = visibleMenu else { return }
        for item in holdItems { menu.removeItem(item) }
        holdHeading.isHidden = holds.holds.isEmpty
        holdItems = holds.holds.map { hold in
            let item = NSMenuItem(title: holdLabel(hold, includePID: true), action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.indentationLevel = 1
            return item
        }
        if !holdItems.isEmpty { holdItems.append(.separator()) }
        let start = menu.index(of: holdHeading) + 1
        for (offset, item) in holdItems.enumerated() {
            menu.insertItem(item, at: start + offset)
        }
    }

    private var lidCloseTitle: String {
        preferences.preventLidCloseSleep
            ? "⚠ Prevent system sleep with lid closed"
            : "Prevent system sleep with lid closed"
    }

    private func togglePreference(_ id: PreferenceMenuRowID) {
        switch id {
        case .preventDisplaySleep:
            togglePreventDisplaySleep()
        case .preventDiskSleep:
            togglePreventDiskSleep()
        case .preventLidCloseSleep:
            togglePreventLidCloseSleep()
        case .playLidEventSounds:
            toggleLidEventSoundPreference(\.playLidEventSounds)
        case .overrideSystemVolumeForLidEventSounds:
            toggleLidEventSoundPreference(\.overrideSystemVolumeForLidEventSounds)
        case .stayUnlockedWithLidClosed:
            toggleLidEventSoundPreference(\.stayUnlockedWithLidClosed)
        }
    }

    private func togglePreventDiskSleep() {
        coordinator.setPreventDiskSleep(!preferences.preventDiskSleep)
    }

    private func addCheckboxRow(
        to menu: NSMenu,
        id: PreferenceRowID,
        title: String,
        isOn: Bool,
        isEnabled: Bool,
        isChild: Bool = false,
        action: @escaping () -> Void
    ) {
        let item = NSMenuItem()
        let row = CheckboxMenuItemView(title: title, isOn: isOn, isEnabled: isEnabled, isChild: isChild)
        row.onToggle = action
        item.view = row
        menu.addItem(item)
        visibleRows[id] = row
    }

    private func refreshVisibleRows() {
        for row in PreferenceMenuRows.rows(for: preferences.snapshot(), showDiskSleep: diskTypeDetector.hasNonSSDDrive) {
            guard let id = PreferenceRowID(row.id) else { continue }
            visibleRows[id]?.update(
                title: row.title,
                isOn: row.isOn,
                isEnabled: row.isEnabled
            )
        }
        visibleRows[.launchAtLogin]?.update(
            title: "Launch at login",
            isOn: launchAtLoginController.isEnabled,
            isEnabled: true
        )
    }

    private func togglePreventDisplaySleep() {
        let newValue = !preferences.preventDisplaySleep
        coordinator.setPreventDisplaySleep(newValue)
        refreshVisibleRows()
    }

    private func togglePreventLidCloseSleep() {
        let newValue = !preferences.preventLidCloseSleep
        if newValue && !preferences.lidClosePreventionConfirmed {
            guard confirmLidClosePreventionEnable() else {
                refreshVisibleRows()
                return
            }
            preferences.lidClosePreventionConfirmed = true
        }
        if !newValue {
            preferences.lidClosePreventionConfirmed = false
        }
        coordinator.setPreventLidCloseSleep(newValue)
        if newValue && !preferences.preventLidCloseSleep {
            preferences.lidClosePreventionConfirmed = false
        }
        refreshVisibleRows()
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

    private func toggleLidEventSoundPreference(_ keyPath: ReferenceWritableKeyPath<PreferencesStore, Bool>) {
        guard preferences.preventLidCloseSleep else {
            refreshVisibleRows()
            return
        }
        preferences[keyPath: keyPath].toggle()
        refreshVisibleRows()
    }

    private func toggleLaunchAtLogin() {
        do {
            try launchAtLoginController.setEnabled(!launchAtLoginController.isEnabled)
            launchAtLoginErrorMessage = nil
        } catch {
            launchAtLoginErrorMessage = error.localizedDescription
        }
        refreshVisibleRows()
    }

    @objc
    private func showAbout() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController(updater: updater)
        }
        aboutWindowController?.showWindow()
    }

    private func setMode(_ mode: ActivationMode) {
        preferences.activationMode = mode
        holds.setMode(mode)
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}
