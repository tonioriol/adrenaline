import Foundation

public enum AdrenalineHelperConstants {
    public static let appBundleIdentifier = "com.tonioriol.adrenaline"
    public static let helperBundleIdentifier = "com.tonioriol.adrenaline.helper"
    public static let appCodeSigningRequirement = "anchor apple generic and identifier \"com.tonioriol.adrenaline\" and certificate leaf[subject.OU] = \"B65K228Z97\" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
    public static let helperCodeSigningRequirement = "anchor apple generic and identifier \"com.tonioriol.adrenaline.helper\" and certificate leaf[subject.OU] = \"B65K228Z97\" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
    public static let helperVersion = 1
}

@objc(AdrenalineHelperProtocol)
public protocol AdrenalineHelperProtocol {
    /// Enables lid-close sleep prevention. Reply values are `(success, errorMessage)`;
    /// `errorMessage == nil` means success, while non-nil contains the helper-reported failure.
    func enableLidClosePrevention(reply: @escaping (NSNumber, NSString?) -> Void)

    /// Disables lid-close sleep prevention. Reply values are `(success, errorMessage)`;
    /// `errorMessage == nil` means success, while non-nil contains the helper-reported failure.
    func disableLidClosePrevention(reply: @escaping (NSNumber, NSString?) -> Void)

    /// Reads the actual lid-close prevention status. Reply values are `(enabled, errorMessage)`;
    /// `errorMessage == nil` means the first value is the current enabled status, while non-nil
    /// contains the helper-reported failure.
    func readLidClosePreventionStatus(reply: @escaping (NSNumber, NSString?) -> Void)

    /// Returns the helper contract version.
    func helperVersion(reply: @escaping (NSNumber) -> Void)
}

public protocol PrivilegedHelperClientProtocol: AnyObject {
    func installOrUpdateHelperIfNeeded() async throws
    func enableLidClosePrevention() async throws
    func disableLidClosePrevention() async throws
    func readLidClosePreventionStatus() async throws -> Bool
}
