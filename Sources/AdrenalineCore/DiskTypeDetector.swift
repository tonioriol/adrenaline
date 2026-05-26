import Foundation
import IOKit

public protocol DiskTypeDetecting {
    var hasNonSSDDrive: Bool { get }
}

public final class DiskTypeDetector: DiskTypeDetecting {
    public let hasNonSSDDrive: Bool

    public init() {
        self.hasNonSSDDrive = Self.detectNonSSDDrive()
    }

    init(hasNonSSDDrive: Bool) {
        self.hasNonSSDDrive = hasNonSSDDrive
    }

    private static func detectNonSSDDrive() -> Bool {
        var iterator = io_iterator_t()
        guard let matching = IOServiceMatching("IOBlockStorageDevice") else { return false }
        guard IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return false
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }

            // Skip devices without characteristics (e.g. card readers without media)
            guard let cfProperties = IORegistryEntryCreateCFProperty(
                service,
                "Device Characteristics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? NSDictionary else {
                continue
            }

            // Only consider devices that explicitly report a medium type.
            // Card readers and controllers often omit this key — skip them.
            guard let mediumType = cfProperties["Medium Type"] as? String else {
                continue
            }

            // "Solid State" is the known SSD value. Anything else
            // (e.g. "Rotational") is a mechanical drive worth protecting.
            if mediumType != "Solid State" {
                return true
            }
        }
        return false
    }
}
