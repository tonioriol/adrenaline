import Combine
import Foundation

public struct PreferencesSnapshot: Equatable, Sendable {
    public var preventDisplaySleep: Bool
    public var preventLidCloseSleep: Bool
    public var playLidEventSounds: Bool

    public init(
        preventDisplaySleep: Bool,
        preventLidCloseSleep: Bool,
        playLidEventSounds: Bool
    ) {
        self.preventDisplaySleep = preventDisplaySleep
        self.preventLidCloseSleep = preventLidCloseSleep
        self.playLidEventSounds = playLidEventSounds
    }
}

@MainActor
public protocol PreferencesProviding: AnyObject {
    var preventDisplaySleep: Bool { get set }
    var preventLidCloseSleep: Bool { get set }
    var playLidEventSounds: Bool { get set }
    var lidClosePreventionConfirmed: Bool { get set }
    var wasActive: Bool { get set }

    var preventDisplaySleepPublisher: AnyPublisher<Bool, Never> { get }
    var preventLidCloseSleepPublisher: AnyPublisher<Bool, Never> { get }
    var playLidEventSoundsPublisher: AnyPublisher<Bool, Never> { get }

    func snapshot() -> PreferencesSnapshot
}

@MainActor
public final class PreferencesStore: ObservableObject, PreferencesProviding {
    public enum Key {
        public static let preventDisplaySleep = "Adrenaline.preventDisplaySleep"
        public static let preventLidCloseSleep = "Adrenaline.preventLidCloseSleep"
        public static let playLidEventSounds = "Adrenaline.playLidEventSounds"
        public static let lidClosePreventionConfirmed = "Adrenaline.lidClosePreventionConfirmed"
        public static let wasActive = "Adrenaline.wasActive"
    }

    private let defaults: UserDefaults

    @Published public var preventDisplaySleep: Bool {
        didSet { defaults.set(preventDisplaySleep, forKey: Key.preventDisplaySleep) }
    }

    @Published public var preventLidCloseSleep: Bool {
        didSet { defaults.set(preventLidCloseSleep, forKey: Key.preventLidCloseSleep) }
    }

    @Published public var playLidEventSounds: Bool {
        didSet { defaults.set(playLidEventSounds, forKey: Key.playLidEventSounds) }
    }

    @Published public var lidClosePreventionConfirmed: Bool {
        didSet { defaults.set(lidClosePreventionConfirmed, forKey: Key.lidClosePreventionConfirmed) }
    }

    @Published public var wasActive: Bool {
        didSet { defaults.set(wasActive, forKey: Key.wasActive) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.preventDisplaySleep = Self.readBool(from: defaults, key: Key.preventDisplaySleep, default: true)
        self.preventLidCloseSleep = Self.readBool(from: defaults, key: Key.preventLidCloseSleep, default: false)
        self.playLidEventSounds = Self.readBool(from: defaults, key: Key.playLidEventSounds, default: true)
        self.lidClosePreventionConfirmed = Self.readBool(from: defaults, key: Key.lidClosePreventionConfirmed, default: false)
        self.wasActive = Self.readBool(from: defaults, key: Key.wasActive, default: false)
    }

    public var preventDisplaySleepPublisher: AnyPublisher<Bool, Never> {
        $preventDisplaySleep.eraseToAnyPublisher()
    }

    public var preventLidCloseSleepPublisher: AnyPublisher<Bool, Never> {
        $preventLidCloseSleep.eraseToAnyPublisher()
    }

    public var playLidEventSoundsPublisher: AnyPublisher<Bool, Never> {
        $playLidEventSounds.eraseToAnyPublisher()
    }

    public func snapshot() -> PreferencesSnapshot {
        PreferencesSnapshot(
            preventDisplaySleep: preventDisplaySleep,
            preventLidCloseSleep: preventLidCloseSleep,
            playLidEventSounds: playLidEventSounds
        )
    }

    private static func readBool(from defaults: UserDefaults, key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }
}
