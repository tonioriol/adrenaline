import Foundation
import IOKit

public enum LidStateMonitorError: Error, LocalizedError, Equatable {
    case rootDomainUnavailable
    case notificationPortUnavailable
    case runLoopSourceUnavailable
    case interestNotificationFailed(kern_return_t)

    public var errorDescription: String? {
        switch self {
        case .rootDomainUnavailable:
            return "IOPM root domain is unavailable"
        case .notificationPortUnavailable:
            return "Could not create lid-state notification port"
        case .runLoopSourceUnavailable:
            return "Could not create lid-state run loop source"
        case let .interestNotificationFailed(code):
            return "Could not register lid-state notifications: IOReturn \(code)"
        }
    }
}

@MainActor
public final class LidStateMonitor: LidStateMonitoring {
    nonisolated static let clamshellStateChangeMessage: UInt32 = (0x38 << 26) | (13 << 14) | 0x100
    nonisolated static let clamshellStateBit: UInt = 1 << 0

    public var onLidStateChange: (@MainActor (LidState) -> Void)?
    public private(set) var isMonitoring = false

    private var rootDomain: io_service_t = 0
    private var notificationPort: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private var runLoopSource: CFRunLoopSource?

    public init() {}

    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        if notifier != 0 {
            IOObjectRelease(notifier)
        }

        if rootDomain != 0 {
            IOObjectRelease(rootDomain)
        }

        if let notificationPort {
            IONotificationPortDestroy(notificationPort)
        }
    }

    public func start() throws {
        guard !isMonitoring else { return }

        let root = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPMrootDomain")
        )
        guard root != 0 else {
            throw LidStateMonitorError.rootDomainUnavailable
        }

        guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
            IOObjectRelease(root)
            throw LidStateMonitorError.notificationPortUnavailable
        }

        guard let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() else {
            IOObjectRelease(root)
            IONotificationPortDestroy(port)
            throw LidStateMonitorError.runLoopSourceUnavailable
        }

        var localNotifier = io_object_t()
        let result = IOServiceAddInterestNotification(
            port,
            root,
            kIOGeneralInterest,
            LidStateMonitor.handleInterestNotification,
            Unmanaged.passUnretained(self).toOpaque(),
            &localNotifier
        )

        guard result == KERN_SUCCESS else {
            IOObjectRelease(root)
            IONotificationPortDestroy(port)
            throw LidStateMonitorError.interestNotificationFailed(result)
        }

        rootDomain = root
        notificationPort = port
        notifier = localNotifier
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        isMonitoring = true
    }

    public func stop() {
        guard isMonitoring else { return }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }

        if notifier != 0 {
            IOObjectRelease(notifier)
            notifier = 0
        }

        if rootDomain != 0 {
            IOObjectRelease(rootDomain)
            rootDomain = 0
        }

        if let port = notificationPort {
            IONotificationPortDestroy(port)
            notificationPort = nil
        }

        isMonitoring = false
    }

    nonisolated static func lidState(fromClamshellMessageArgument messageArgument: UInt) -> LidState {
        (messageArgument & clamshellStateBit) == 0 ? .open : .closed
    }

    private nonisolated static let handleInterestNotification: IOServiceInterestCallback = { refcon, _, messageType, messageArgument in
        guard messageType == LidStateMonitor.clamshellStateChangeMessage,
              let refcon else { return }

        let monitor = Unmanaged<LidStateMonitor>.fromOpaque(refcon).takeUnretainedValue()
        let argument = UInt(bitPattern: messageArgument)
        let lidState = LidStateMonitor.lidState(fromClamshellMessageArgument: argument)

        Task { @MainActor in
            monitor.onLidStateChange?(lidState)
        }
    }
}
