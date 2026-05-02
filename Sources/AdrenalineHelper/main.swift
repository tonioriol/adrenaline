import Foundation
import AdrenalineCore

final class HelperDelegate: NSObject, NSXPCListenerDelegate, AdrenalineHelperProtocol {
    private let powerSettings = ApplePowerSettings()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: AdrenalineHelperProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func enableLidClosePrevention(reply: @escaping (NSNumber, NSString?) -> Void) {
        setLidClosePrevention(true, reply: reply)
    }

    func disableLidClosePrevention(reply: @escaping (NSNumber, NSString?) -> Void) {
        setLidClosePrevention(false, reply: reply)
    }

    func readLidClosePreventionStatus(reply: @escaping (NSNumber, NSString?) -> Void) {
        do {
            let enabled = try powerSettings.isLidClosePreventionEnabled()
            reply(NSNumber(value: enabled), nil)
        } catch {
            reply(false, error.localizedDescription as NSString)
        }
    }

    func helperVersion(reply: @escaping (NSNumber) -> Void) {
        reply(NSNumber(value: AdrenalineHelperConstants.helperVersion))
    }

    private func setLidClosePrevention(_ enabled: Bool, reply: @escaping (NSNumber, NSString?) -> Void) {
        do {
            try powerSettings.setLidClosePreventionEnabled(enabled)
            let actual = try powerSettings.isLidClosePreventionEnabled()
            reply(NSNumber(value: actual == enabled), nil)
        } catch {
            reply(false, error.localizedDescription as NSString)
        }
    }
}

let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: AdrenalineHelperConstants.helperBundleIdentifier)
listener.delegate = delegate
listener.setConnectionCodeSigningRequirement(AdrenalineHelperConstants.appCodeSigningRequirement)
listener.resume()
RunLoop.current.run()
