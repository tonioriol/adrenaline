import Foundation
import AdrenalineCore
import os.log
import Sparkle

final class SparkleUpdaterController: NSObject, Updating, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    private static let log = OSLog(subsystem: "com.tonioriol.adrenaline", category: "updater")

    private var controller: SPUStandardUpdaterController!
    private var currentStatus: UpdaterStatus = .idle(lastChecked: nil)

    /// Guards `resultHandled` across delegate callbacks.
    private let resultLock = NSLock()
    /// Set synchronously by specific callbacks (didFindValidUpdate,
    /// updaterDidNotFindUpdate) before dispatching to the main queue.
    /// `didFinishUpdateCycleFor` checks and resets this flag to decide
    /// whether to act — avoiding an ordering race where it could
    /// overwrite a status already set by a specific callback.
    private var resultHandled = false

    var automaticallyDownloadsUpdates: Bool {
        get { controller.updater.automaticallyDownloadsUpdates }
        set {
            controller.updater.automaticallyDownloadsUpdates = newValue
            // Sparkle uses a separate UserDefaults flag for silent *install*
            // after background download. Keep both in sync so the single
            // "Automatically install updates" checkbox controls the full chain.
            UserDefaults.standard.set(newValue, forKey: "SUAutomaticallyUpdate")
        }
    }

    var lastUpdateCheckDate: Date? {
        controller.updater.lastUpdateCheckDate
    }

    var onStatusChange: ((UpdaterStatus) -> Void)? {
        didSet {
            if let onStatusChange {
                onStatusChange(currentStatus)
            }
        }
    }

    override init() {
        super.init()
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: self
        )
        currentStatus = .idle(lastChecked: controller.updater.lastUpdateCheckDate)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    private func publishStatus(_ status: UpdaterStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentStatus = status
            self.onStatusChange?(status)
        }
    }

    // MARK: - SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        // No-op; Sparkle uses thrown errors to veto a check. We allow all checks.
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        // Check flag synchronously — no Task ordering issues.
        let alreadyHandled = resultLock.withLock {
            let v = resultHandled
            resultHandled = false // reset for next cycle
            return v
        }
        guard !alreadyHandled else { return }

        // No specific callback fired — handle the result here.
        if let error {
            os_log("update check failed: %{public}@", log: Self.log, type: .error, String(describing: error))
            publishStatus(.error(error.localizedDescription))
        } else {
            publishStatus(.idle(lastChecked: controller.updater.lastUpdateCheckDate))
        }
    }

    func updaterMayCheck(forUpdates updater: SPUUpdater) -> Bool {
        publishStatus(.checking)
        return true
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        resultLock.withLock { resultHandled = true }
        let displayVersion = item.displayVersionString
        os_log("update available: %{public}@", log: Self.log, type: .info, displayVersion)
        publishStatus(.updateAvailable(version: displayVersion))
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        resultLock.withLock { resultHandled = true }
        os_log("up to date", log: Self.log, type: .info)
        publishStatus(.upToDate)
    }

}
