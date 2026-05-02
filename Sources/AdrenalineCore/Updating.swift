import Combine
import Foundation

public enum UpdaterStatus: Equatable, Sendable {
    case idle(lastChecked: Date?)
    case checking
    case updateAvailable(version: String)
    case upToDate
    case error(String)
}

@MainActor
public protocol Updating: AnyObject {
    var automaticallyDownloadsUpdates: Bool { get set }
    var lastUpdateCheckDate: Date? { get }
    var statusPublisher: AnyPublisher<UpdaterStatus, Never> { get }
    func checkForUpdates()
}
