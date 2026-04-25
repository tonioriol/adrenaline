import Foundation

public enum CocaineHelperConstants {
    public static let appBundleIdentifier = "com.tr0n.Cocaine"
    public static let helperBundleIdentifier = "com.tr0n.Cocaine.Helper"
    public static let appCodeSigningRequirement = "anchor apple generic and identifier \"com.tr0n.Cocaine\" and certificate leaf[subject.OU] = \"A79T83GM42\""
    public static let helperCodeSigningRequirement = "anchor apple generic and identifier \"com.tr0n.Cocaine.Helper\" and certificate leaf[subject.OU] = \"A79T83GM42\""
    public static let helperVersion = 1
}

@objc(CocaineHelperProtocol)
public protocol CocaineHelperProtocol {
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
