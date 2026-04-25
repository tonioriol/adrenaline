import Foundation
import CocaineCore

final class HelperDelegate: NSObject, NSXPCListenerDelegate, CocaineHelperProtocol {
    private let powerSettings = ApplePowerSettings()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: CocaineHelperProtocol.self)
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
        reply(NSNumber(value: CocaineHelperConstants.helperVersion))
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
let listener = NSXPCListener(machServiceName: CocaineHelperConstants.helperBundleIdentifier)
listener.delegate = delegate
listener.setConnectionCodeSigningRequirement(CocaineHelperConstants.appCodeSigningRequirement)
listener.resume()
RunLoop.current.run()
