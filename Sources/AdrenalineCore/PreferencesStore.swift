import Foundation

public struct PreferencesSnapshot: Equatable {
    public var preventDisplaySleep: Bool
    public var preventLidCloseSleep: Bool
    public var preventDiskSleep: Bool
    public var playLidEventSounds: Bool
    public var overrideSystemVolumeForLidEventSounds: Bool
    public var stayUnlockedWithLidClosed: Bool

    public init(
        preventDisplaySleep: Bool,
        preventLidCloseSleep: Bool,
        preventDiskSleep: Bool = true,
        playLidEventSounds: Bool,
        overrideSystemVolumeForLidEventSounds: Bool = true,
        stayUnlockedWithLidClosed: Bool = false
    ) {
        self.preventDisplaySleep = preventDisplaySleep
        self.preventLidCloseSleep = preventLidCloseSleep
        self.preventDiskSleep = preventDiskSleep
        self.playLidEventSounds = playLidEventSounds
        self.overrideSystemVolumeForLidEventSounds = overrideSystemVolumeForLidEventSounds
        self.stayUnlockedWithLidClosed = stayUnlockedWithLidClosed
    }
}

public extension Notification.Name {
    static let preferencesPreventDisplaySleepDidChange = Notification.Name("Adrenaline.preferencesPreventDisplaySleepDidChange")
    static let preferencesPreventLidCloseSleepDidChange = Notification.Name("Adrenaline.preferencesPreventLidCloseSleepDidChange")
    static let preferencesPreventDiskSleepDidChange = Notification.Name("Adrenaline.preferencesPreventDiskSleepDidChange")
    static let preferencesPlayLidEventSoundsDidChange = Notification.Name("Adrenaline.preferencesPlayLidEventSoundsDidChange")
    static let preferencesOverrideSystemVolumeForLidEventSoundsDidChange = Notification.Name("Adrenaline.preferencesOverrideSystemVolumeForLidEventSoundsDidChange")
    static let preferencesStayUnlockedWithLidClosedDidChange = Notification.Name("Adrenaline.preferencesStayUnlockedWithLidClosedDidChange")
}

public protocol PreferencesProviding: AnyObject {
    var preventDisplaySleep: Bool { get set }
    var preventLidCloseSleep: Bool { get set }
    var preventDiskSleep: Bool { get set }
    var playLidEventSounds: Bool { get set }
    var overrideSystemVolumeForLidEventSounds: Bool { get set }
    var stayUnlockedWithLidClosed: Bool { get set }
    var lidClosePreventionConfirmed: Bool { get set }

    func snapshot() -> PreferencesSnapshot
}

/// The settings Auto and On each keep their own copy of.
public enum PresetSetting: String, CaseIterable {
    case preventDisplaySleep
    case preventLidCloseSleep
    case preventDiskSleep
    case playLidEventSounds
    case overrideSystemVolumeForLidEventSounds
    case stayUnlockedWithLidClosed

    var defaultValue: Bool {
        switch self {
        case .preventDisplaySleep, .preventDiskSleep, .playLidEventSounds, .overrideSystemVolumeForLidEventSounds:
            return true
        case .preventLidCloseSleep, .stayUnlockedWithLidClosed:
            return false
        }
    }

    var didChange: Notification.Name {
        switch self {
        case .preventDisplaySleep: return .preferencesPreventDisplaySleepDidChange
        case .preventLidCloseSleep: return .preferencesPreventLidCloseSleepDidChange
        case .preventDiskSleep: return .preferencesPreventDiskSleepDidChange
        case .playLidEventSounds: return .preferencesPlayLidEventSoundsDidChange
        case .overrideSystemVolumeForLidEventSounds: return .preferencesOverrideSystemVolumeForLidEventSoundsDidChange
        case .stayUnlockedWithLidClosed: return .preferencesStayUnlockedWithLidClosedDidChange
        }
    }

    /// The single key all modes shared before presets; both presets start from it.
    var legacyKey: String { "Adrenaline.\(rawValue)" }

    func key(for preset: ActivationMode) -> String { "Adrenaline.\(preset.rawValue).\(rawValue)" }
}

public final class PreferencesStore: PreferencesProviding {
    public enum Key {
        public static let lidClosePreventionConfirmed = "Adrenaline.lidClosePreventionConfirmed"
        public static let activationMode = "Adrenaline.activationMode"
        fileprivate static let wasActive = "Adrenaline.wasActive"
    }

    private let defaults: UserDefaults
    private var presets: [ActivationMode: [PresetSetting: Bool]] = [:]

    public var activationMode: ActivationMode {
        didSet {
            defaults.set(activationMode.rawValue, forKey: Key.activationMode)
            let previous = Self.preset(for: oldValue)
            for setting in PresetSetting.allCases where presets[previous]?[setting] != presets[preset]?[setting] {
                NotificationCenter.default.post(name: setting.didChange, object: self)
            }
        }
    }

    /// The preset the settings read and write: Auto's in Auto, On's in On and Off.
    public var preset: ActivationMode { Self.preset(for: activationMode) }

    public var preventDisplaySleep: Bool {
        get { self[.preventDisplaySleep] }
        set { self[.preventDisplaySleep] = newValue }
    }

    public var preventLidCloseSleep: Bool {
        get { self[.preventLidCloseSleep] }
        set { self[.preventLidCloseSleep] = newValue }
    }

    public var preventDiskSleep: Bool {
        get { self[.preventDiskSleep] }
        set { self[.preventDiskSleep] = newValue }
    }

    public var playLidEventSounds: Bool {
        get { self[.playLidEventSounds] }
        set { self[.playLidEventSounds] = newValue }
    }

    public var overrideSystemVolumeForLidEventSounds: Bool {
        get { self[.overrideSystemVolumeForLidEventSounds] }
        set { self[.overrideSystemVolumeForLidEventSounds] = newValue }
    }

    public var stayUnlockedWithLidClosed: Bool {
        get { self[.stayUnlockedWithLidClosed] }
        set { self[.stayUnlockedWithLidClosed] = newValue }
    }

    public var lidClosePreventionConfirmed: Bool {
        didSet { defaults.set(lidClosePreventionConfirmed, forKey: Key.lidClosePreventionConfirmed) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.lidClosePreventionConfirmed = defaults.object(forKey: Key.lidClosePreventionConfirmed) as? Bool ?? false
        if let saved = defaults.string(forKey: Key.activationMode), let mode = ActivationMode(rawValue: saved) {
            self.activationMode = mode
        } else {
            self.activationMode = defaults.bool(forKey: Key.wasActive) ? .on : .auto
            defaults.set(activationMode.rawValue, forKey: Key.activationMode)
        }
        for preset in [ActivationMode.auto, .on] {
            var values: [PresetSetting: Bool] = [:]
            for setting in PresetSetting.allCases {
                values[setting] = defaults.object(forKey: setting.key(for: preset)) as? Bool
                    ?? defaults.object(forKey: setting.legacyKey) as? Bool
                    ?? setting.defaultValue
            }
            presets[preset] = values
        }
    }

    public subscript(setting: PresetSetting) -> Bool {
        get { presets[preset]?[setting] ?? setting.defaultValue }
        set {
            let previous = self[setting]
            presets[preset, default: [:]][setting] = newValue
            defaults.set(newValue, forKey: setting.key(for: preset))
            if newValue != previous {
                NotificationCenter.default.post(name: setting.didChange, object: self)
            }
        }
    }

    public func snapshot() -> PreferencesSnapshot {
        PreferencesSnapshot(
            preventDisplaySleep: preventDisplaySleep,
            preventLidCloseSleep: preventLidCloseSleep,
            preventDiskSleep: preventDiskSleep,
            playLidEventSounds: playLidEventSounds,
            overrideSystemVolumeForLidEventSounds: overrideSystemVolumeForLidEventSounds,
            stayUnlockedWithLidClosed: stayUnlockedWithLidClosed
        )
    }

    private static func preset(for mode: ActivationMode) -> ActivationMode {
        mode == .auto ? .auto : .on
    }
}
