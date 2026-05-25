import Foundation

public enum UpdaterStatus: Equatable {
    case idle(lastChecked: Date?)
    case checking
    case updateAvailable(version: String)
    case upToDate
    case error(String)
}

public protocol Updating: AnyObject {
    var automaticallyDownloadsUpdates: Bool { get set }
    var lastUpdateCheckDate: Date? { get }
    var onStatusChange: ((UpdaterStatus) -> Void)? { get set }
    func checkForUpdates()
}
