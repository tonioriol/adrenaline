public enum PreferenceMenuRowID: Hashable, Sendable {
    case preventDisplaySleep
    case preventLidCloseSleep
    case lockScreenOnLidClose
    case playLidEventSounds
}

public struct PreferenceMenuRow: Equatable, Sendable {
    public let id: PreferenceMenuRowID
    public let title: String
    public let isOn: Bool
    public let isEnabled: Bool
    public let isChild: Bool

    public init(id: PreferenceMenuRowID, title: String, isOn: Bool, isEnabled: Bool, isChild: Bool = false) {
        self.id = id
        self.title = title
        self.isOn = isOn
        self.isEnabled = isEnabled
        self.isChild = isChild
    }
}

public enum PreferenceMenuRows {
    public static func rows(for snapshot: PreferencesSnapshot) -> [PreferenceMenuRow] {
        [
            PreferenceMenuRow(
                id: .preventDisplaySleep,
                title: "Prevent display sleep",
                isOn: snapshot.preventDisplaySleep,
                isEnabled: true),
            PreferenceMenuRow(
                id: .preventLidCloseSleep,
                title: snapshot.preventLidCloseSleep
                    ? "⚠ Prevent system sleep with lid closed"
                    : "Prevent system sleep with lid closed",
                isOn: snapshot.preventLidCloseSleep,
                isEnabled: true),
            PreferenceMenuRow(
                id: .lockScreenOnLidClose,
                title: "Lock screen on lid close",
                isOn: snapshot.lockScreenOnLidClose,
                isEnabled: snapshot.preventLidCloseSleep,
                isChild: true),
            PreferenceMenuRow(
                id: .playLidEventSounds,
                title: "Play lid event sounds",
                isOn: snapshot.playLidEventSounds,
                isEnabled: snapshot.preventLidCloseSleep,
                isChild: true),
        ]
    }
}
