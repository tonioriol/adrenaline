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

            guard let cfProperties = IORegistryEntryCreateCFProperty(
                service,
                "Device Characteristics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? NSDictionary else {
                return true
            }

            if let mediumType = cfProperties["Medium Type"] as? String {
                if mediumType != "Solid State" {
                    return true
                }
            } else {
                return true
            }
        }
        return false
    }
}
