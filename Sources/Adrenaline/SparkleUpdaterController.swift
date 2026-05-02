import Combine
import Foundation
import AdrenalineCore
import os.log
import Sparkle

@MainActor
final class SparkleUpdaterController: NSObject, Updating, SPUUpdaterDelegate {
    private static let log = OSLog(subsystem: "com.tonioriol.insomnia", category: "updater")

    private var controller: SPUStandardUpdaterController!
    private let statusSubject: CurrentValueSubject<UpdaterStatus, Never>

    /// Guards `_resultHandled` across nonisolated delegate callbacks.
    private nonisolated(unsafe) let resultLock = NSLock()
    /// Set synchronously by specific callbacks (didFindValidUpdate,
    /// updaterDidNotFindUpdate) *before* dispatching to MainActor.
    /// `didFinishUpdateCycleFor` checks and resets this flag to decide
    /// whether to act — avoiding a Task-ordering race where it could
    /// overwrite a status already set by a specific callback.
    private nonisolated(unsafe) var _resultHandled = false

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

    var statusPublisher: AnyPublisher<UpdaterStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    override init() {
        self.statusSubject = CurrentValueSubject(.idle(lastChecked: nil))
        super.init()
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        statusSubject.value = .idle(lastChecked: controller.updater.lastUpdateCheckDate)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    // MARK: - SPUUpdaterDelegate

    nonisolated func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        // No-op; Sparkle uses thrown errors to veto a check. We allow all checks.
    }

    nonisolated func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        // Check flag synchronously — no Task ordering issues.
        let alreadyHandled = resultLock.withLock {
            let v = _resultHandled
            _resultHandled = false // reset for next cycle
            return v
        }
        guard !alreadyHandled else { return }

        // No specific callback fired — handle the result here.
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let error {
                os_log("update check failed: %{public}@", log: Self.log, type: .error, String(describing: error))
                self.statusSubject.value = .error(error.localizedDescription)
            } else {
                self.statusSubject.value = .idle(lastChecked: self.controller.updater.lastUpdateCheckDate)
            }
        }
    }

    nonisolated func updaterMayCheck(forUpdates updater: SPUUpdater) -> Bool {
        Task { @MainActor [weak self] in
            self?.statusSubject.value = .checking
        }
        return true
    }

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        resultLock.withLock { _resultHandled = true }
        let displayVersion = item.displayVersionString
        Task { @MainActor [weak self] in
            os_log("update available: %{public}@", log: Self.log, type: .info, displayVersion)
            self?.statusSubject.value = .updateAvailable(version: displayVersion)
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        resultLock.withLock { _resultHandled = true }
        Task { @MainActor [weak self] in
            os_log("up to date", log: Self.log, type: .info)
            self?.statusSubject.value = .upToDate
        }
    }
}
