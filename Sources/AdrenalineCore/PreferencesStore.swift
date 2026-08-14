import Foundation

public struct PreferencesSnapshot: Equatable {
    public var preventDisplaySleep: Bool
    public var preventLidCloseSleep: Bool
    public var preventDiskSleep: Bool
    public var playLidEventSounds: Bool
    public var overrideSystemVolumeForLidEventSounds: Bool

    public init(
        preventDisplaySleep: Bool,
        preventLidCloseSleep: Bool,
        preventDiskSleep: Bool = true,
        playLidEventSounds: Bool,
        overrideSystemVolumeForLidEventSounds: Bool = true
    ) {
        self.preventDisplaySleep = preventDisplaySleep
        self.preventLidCloseSleep = preventLidCloseSleep
        self.preventDiskSleep = preventDiskSleep
        self.playLidEventSounds = playLidEventSounds
        self.overrideSystemVolumeForLidEventSounds = overrideSystemVolumeForLidEventSounds
    }
}

public extension Notification.Name {
    static let preferencesPreventDisplaySleepDidChange = Notification.Name("Adrenaline.preferencesPreventDisplaySleepDidChange")
    static let preferencesPreventLidCloseSleepDidChange = Notification.Name("Adrenaline.preferencesPreventLidCloseSleepDidChange")
    static let preferencesPreventDiskSleepDidChange = Notification.Name("Adrenaline.preferencesPreventDiskSleepDidChange")
    static let preferencesPlayLidEventSoundsDidChange = Notification.Name("Adrenaline.preferencesPlayLidEventSoundsDidChange")
    static let preferencesOverrideSystemVolumeForLidEventSoundsDidChange = Notification.Name("Adrenaline.preferencesOverrideSystemVolumeForLidEventSoundsDidChange")
}

public protocol PreferencesProviding: AnyObject {
    var preventDisplaySleep: Bool { get set }
    var preventLidCloseSleep: Bool { get set }
    var preventDiskSleep: Bool { get set }
    var playLidEventSounds: Bool { get set }
    var overrideSystemVolumeForLidEventSounds: Bool { get set }
    var lidClosePreventionConfirmed: Bool { get set }
    var wasActive: Bool { get set }

    func snapshot() -> PreferencesSnapshot
}

public final class PreferencesStore: PreferencesProviding {
    public enum Key {
        public static let preventDisplaySleep = "Adrenaline.preventDisplaySleep"
        public static let preventLidCloseSleep = "Adrenaline.preventLidCloseSleep"
        public static let preventDiskSleep = "Adrenaline.preventDiskSleep"
        public static let playLidEventSounds = "Adrenaline.playLidEventSounds"
        public static let overrideSystemVolumeForLidEventSounds = "Adrenaline.overrideSystemVolumeForLidEventSounds"
        public static let lidClosePreventionConfirmed = "Adrenaline.lidClosePreventionConfirmed"
        public static let wasActive = "Adrenaline.wasActive"
    }

    private let defaults: UserDefaults

    public var preventDisplaySleep: Bool {
        didSet {
            defaults.set(preventDisplaySleep, forKey: Key.preventDisplaySleep)
            if preventDisplaySleep != oldValue {
                NotificationCenter.default.post(name: .preferencesPreventDisplaySleepDidChange, object: self)
            }
        }
    }

    public var preventLidCloseSleep: Bool {
        didSet {
            defaults.set(preventLidCloseSleep, forKey: Key.preventLidCloseSleep)
            if preventLidCloseSleep != oldValue {
                NotificationCenter.default.post(name: .preferencesPreventLidCloseSleepDidChange, object: self)
            }
        }
    }

    public var preventDiskSleep: Bool {
        didSet {
            defaults.set(preventDiskSleep, forKey: Key.preventDiskSleep)
            if preventDiskSleep != oldValue {
                NotificationCenter.default.post(name: .preferencesPreventDiskSleepDidChange, object: self)
            }
        }
    }

    public var playLidEventSounds: Bool {
        didSet {
            defaults.set(playLidEventSounds, forKey: Key.playLidEventSounds)
            if playLidEventSounds != oldValue {
                NotificationCenter.default.post(name: .preferencesPlayLidEventSoundsDidChange, object: self)
            }
        }
    }

    public var overrideSystemVolumeForLidEventSounds: Bool {
        didSet {
            defaults.set(overrideSystemVolumeForLidEventSounds, forKey: Key.overrideSystemVolumeForLidEventSounds)
            if overrideSystemVolumeForLidEventSounds != oldValue {
                NotificationCenter.default.post(name: .preferencesOverrideSystemVolumeForLidEventSoundsDidChange, object: self)
            }
        }
    }

    public var lidClosePreventionConfirmed: Bool {
        didSet { defaults.set(lidClosePreventionConfirmed, forKey: Key.lidClosePreventionConfirmed) }
    }

    public var wasActive: Bool {
        didSet { defaults.set(wasActive, forKey: Key.wasActive) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.preventDisplaySleep = Self.readBool(from: defaults, key: Key.preventDisplaySleep, default: true)
        self.preventLidCloseSleep = Self.readBool(from: defaults, key: Key.preventLidCloseSleep, default: false)
        self.preventDiskSleep = Self.readBool(from: defaults, key: Key.preventDiskSleep, default: true)
        self.playLidEventSounds = Self.readBool(from: defaults, key: Key.playLidEventSounds, default: true)
        self.overrideSystemVolumeForLidEventSounds = Self.readBool(from: defaults, key: Key.overrideSystemVolumeForLidEventSounds, default: true)
        self.lidClosePreventionConfirmed = Self.readBool(from: defaults, key: Key.lidClosePreventionConfirmed, default: false)
        self.wasActive = Self.readBool(from: defaults, key: Key.wasActive, default: false)
    }

    public func snapshot() -> PreferencesSnapshot {
        PreferencesSnapshot(
            preventDisplaySleep: preventDisplaySleep,
            preventLidCloseSleep: preventLidCloseSleep,
            preventDiskSleep: preventDiskSleep,
            playLidEventSounds: playLidEventSounds,
            overrideSystemVolumeForLidEventSounds: overrideSystemVolumeForLidEventSounds
        )
    }

    private static func readBool(from defaults: UserDefaults, key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }
}
