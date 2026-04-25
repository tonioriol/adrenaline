import Foundation

public enum CocaineHelperConstants {
    public static let appBundleIdentifier = "com.tr0n.Cocaine"
    public static let helperBundleIdentifier = "com.tr0n.Cocaine.Helper"
    public static let helperVersion = 1
}

@objc(CocaineHelperProtocol)
public protocol CocaineHelperProtocol {
    func enableLidClosePrevention(reply: @escaping (NSNumber, NSString?) -> Void)
    func disableLidClosePrevention(reply: @escaping (NSNumber, NSString?) -> Void)
    func readLidClosePreventionStatus(reply: @escaping (NSNumber, NSString?) -> Void)
    func helperVersion(reply: @escaping (NSNumber) -> Void)
}

public protocol PrivilegedHelperClientProtocol: AnyObject {
    func installOrUpdateHelperIfNeeded() async throws
    func enableLidClosePrevention() async throws
    func disableLidClosePrevention() async throws
    func readLidClosePreventionStatus() async throws -> Bool
}
