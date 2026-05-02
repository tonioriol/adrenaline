import XCTest
@testable import InsomniaCore

@MainActor
final class MacOSLockPolicyReaderTests: XCTestCase {
    func testAskForPasswordIntegerOneRequiresPassword() throws {
        let reader = makeReader(screenSaverValues: ["askForPassword": 1])

        let policy = try reader.currentPolicy()

        XCTAssertTrue(policy.requiresPassword)
    }

    func testAskForPasswordBooleanTrueRequiresPassword() throws {
        let reader = makeReader(screenSaverValues: ["askForPassword": true])

        let policy = try reader.currentPolicy()

        XCTAssertTrue(policy.requiresPassword)
    }

    func testAskForPasswordStringTrueRequiresPassword() throws {
        let reader = makeReader(screenSaverValues: ["askForPassword": "true"])

        let policy = try reader.currentPolicy()

        XCTAssertTrue(policy.requiresPassword)
    }

    func testAskForPasswordIntegerZeroDoesNotRequirePassword() throws {
        let reader = makeReader(screenSaverValues: ["askForPassword": 0])

        let policy = try reader.currentPolicy()

        XCTAssertFalse(policy.requiresPassword)
    }

    func testAskForPasswordBooleanFalseDoesNotRequirePassword() throws {
        let reader = makeReader(screenSaverValues: ["askForPassword": false])

        let policy = try reader.currentPolicy()

        XCTAssertFalse(policy.requiresPassword)
    }

    func testMissingAskForPasswordDoesNotRequirePassword() throws {
        let reader = makeReader(screenSaverValues: [:])

        let policy = try reader.currentPolicy()

        XCTAssertFalse(policy.requiresPassword)
    }

    func testInvalidAskForPasswordDoesNotRequirePassword() throws {
        let reader = makeReader(screenSaverValues: ["askForPassword": "not-a-bool"])

        let policy = try reader.currentPolicy()
        XCTAssertFalse(policy.requiresPassword)
    }

    private func makeReader(screenSaverValues: [String: Any]) -> MacOSLockPolicyReader {
        let suiteName = "MacOSLockPolicyReaderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        for (key, value) in screenSaverValues {
            defaults.set(value, forKey: key)
        }

        return MacOSLockPolicyReader(screenSaverDefaults: defaults)
    }
}
