import AppKit
import AdrenalineCore

final class AboutWindowController: NSWindowController {
    private let updater: Updating
    private let statusLabel = NSTextField(labelWithString: "")
    private let autoInstallCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    init(updater: Updating) {
        self.updater = updater

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Adrenaline"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        configureContent()
        bindUpdater()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
    }

    // MARK: - Layout

    private func configureContent() {
        guard let window, let contentView = window.contentView else { return }

        let iconView = NSImageView(image: NSApp.applicationIconImage)
        iconView.imageScaling = .scaleProportionallyUpOrDown

        let nameLabel = NSTextField(labelWithString: "Adrenaline")
        nameLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        nameLabel.alignment = .center

        let versionLabel = NSTextField(labelWithString: Self.versionString())
        versionLabel.font = .systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center

        let creditsLabel = NSTextField(labelWithString: "macOS menu bar sleep prevention utility.")
        creditsLabel.font = .systemFont(ofSize: 11)
        creditsLabel.textColor = .secondaryLabelColor
        creditsLabel.alignment = .center

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center

        let checkButton = NSButton(title: "Check for Updates…", target: self, action: #selector(checkForUpdatesClicked))
        checkButton.bezelStyle = .rounded

        autoInstallCheckbox.title = "Automatically install updates"
        autoInstallCheckbox.target = self
        autoInstallCheckbox.action = #selector(autoInstallToggled(_:))
        autoInstallCheckbox.state = updater.automaticallyDownloadsUpdates ? .on : .off

        let stack = NSStackView(views: [
            iconView,
            nameLabel,
            versionLabel,
            creditsLabel,
            statusLabel,
            checkButton,
            autoInstallCheckbox,
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
    }

    private func bindUpdater() {
        statusLabel.stringValue = statusText(for: .idle(lastChecked: updater.lastUpdateCheckDate))
        updater.onStatusChange = { [weak self] status in
            self?.statusLabel.stringValue = self?.statusText(for: status) ?? ""
        }
    }

    // MARK: - Actions

    @objc private func checkForUpdatesClicked() {
        updater.checkForUpdates()
    }

    @objc private func autoInstallToggled(_ sender: NSButton) {
        updater.automaticallyDownloadsUpdates = (sender.state == .on)
    }

    // MARK: - Helpers

    private func statusText(for status: UpdaterStatus) -> String {
        switch status {
        case .idle(let lastChecked):
            guard let lastChecked else { return "Last checked: never" }
            return "Last checked: \(relativeString(for: lastChecked))"
        case .checking:
            return "Checking for updates…"
        case .updateAvailable(let version):
            return "Update available: \(version)"
        case .upToDate:
            return "You're running the latest version."
        case .error(let message):
            return "Update check failed: \(message)"
        }
    }

    private func relativeString(for date: Date) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 1
        formatter.unitsStyle = .full

        let now = Date()
        if let value = formatter.string(from: date, to: now), !value.isEmpty {
            return "\(value) ago"
        }

        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }

    private static func versionString() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }
}
