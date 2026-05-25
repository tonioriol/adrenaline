import Foundation
import Security
import AdrenalineCore

final class HelperDelegate: NSObject, NSXPCListenerDelegate, AdrenalineHelperProtocol {
    private let powerSettings = ApplePowerSettings()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard HelperDelegate.validateClientCodeSignature(connection: connection) else {
            return false
        }

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

    // MARK: - Code Signing Validation

    private static func validateClientCodeSignature(connection: NSXPCConnection) -> Bool {
        let pid = connection.processIdentifier
        var code: SecCode?
        var attributes = [String: Any]()
        attributes[kSecGuestAttributePid as String] = pid

        let status = SecCodeCopyGuestWithAttributes(nil, attributes as CFDictionary, [], &code)
        guard status == errSecSuccess, let validCode = code else {
            return false
        }

        let requirement = AdrenalineHelperConstants.appCodeSigningRequirement
        var secRequirement: SecRequirement?
        guard SecRequirementCreateWithString(requirement as CFString, [], &secRequirement) == errSecSuccess,
              let validRequirement = secRequirement else {
            return false
        }

        return SecCodeCheckValidity(validCode, [], validRequirement) == errSecSuccess
    }
}

let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: AdrenalineHelperConstants.helperBundleIdentifier)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
