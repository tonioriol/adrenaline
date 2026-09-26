import AppKit

enum LoginPasswordPrompt {
    /// Asks for the user's login password. Returns nil when cancelled.
    static func run(retry: Bool) -> String? {
        let alert = NSAlert()
        alert.messageText = retry ? "That password didn't work" : "Stay unlocked when lid is closed"
        alert.informativeText = "macOS only lets the \"Require password\" lock setting change with your login password. " +
            "Adrenaline turns it off while it's on and puts your setting back when it turns off. " +
            "The password is kept in your Keychain."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "Login password for \(NSUserName())"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty else { return nil }
        return field.stringValue
    }
}
