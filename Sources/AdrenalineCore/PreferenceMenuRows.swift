public enum PreferenceMenuRowID: Hashable {
    case preventDisplaySleep
    case preventDiskSleep
    case preventLidCloseSleep
    case playLidEventSounds
    case overrideSystemVolumeForLidEventSounds
}

public struct PreferenceMenuRow: Equatable {
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
    public static func rows(for snapshot: PreferencesSnapshot, showDiskSleep: Bool = false) -> [PreferenceMenuRow] {
        var result: [PreferenceMenuRow] = [
            PreferenceMenuRow(
                id: .preventDisplaySleep,
                title: "Prevent display sleep",
                isOn: snapshot.preventDisplaySleep,
                isEnabled: true),
        ]

        if showDiskSleep {
            result.append(PreferenceMenuRow(
                id: .preventDiskSleep,
                title: "Prevent disk sleep",
                isOn: snapshot.preventDiskSleep,
                isEnabled: true))
        }

        result.append(PreferenceMenuRow(
            id: .preventLidCloseSleep,
            title: snapshot.preventLidCloseSleep
                ? "⚠ Prevent system sleep with lid closed"
                : "Prevent system sleep with lid closed",
            isOn: snapshot.preventLidCloseSleep,
            isEnabled: true))
        result.append(PreferenceMenuRow(
            id: .playLidEventSounds,
            title: "Play lid event sounds",
            isOn: snapshot.playLidEventSounds,
            isEnabled: snapshot.preventLidCloseSleep,
            isChild: true))
        result.append(PreferenceMenuRow(
            id: .overrideSystemVolumeForLidEventSounds,
            title: "Override system volume for lid event sounds",
            isOn: snapshot.overrideSystemVolumeForLidEventSounds,
            isEnabled: snapshot.preventLidCloseSleep,
            isChild: true))

        return result
    }
}
