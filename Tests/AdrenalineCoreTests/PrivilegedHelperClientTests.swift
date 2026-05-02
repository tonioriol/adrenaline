import XCTest
@testable import AdrenalineCore

final class PrivilegedHelperClientTests: XCTestCase {
    func testDecodeBooleanReplyThrowsHelperReturnedErrorForErrorMessage() {
        XCTAssertThrowsError(
            try PrivilegedHelperClient.decodeBooleanReply(
                false,
                errorMessage: "boom",
                requiresSuccess: true
            )
        ) { error in
            XCTAssertEqual(error as? PrivilegedHelperClientError, .helperReturnedError("boom"))
        }
    }

    func testDecodeBooleanReplyThrowsInvalidReplyForFailedMutatingCommandWithoutError() {
        XCTAssertThrowsError(
            try PrivilegedHelperClient.decodeBooleanReply(
                false,
                errorMessage: nil,
                requiresSuccess: true
            )
        ) { error in
            XCTAssertEqual(error as? PrivilegedHelperClientError, .invalidReply)
        }
    }

    func testDecodeBooleanReplyAllowsFalseStatusWithoutError() throws {
        let value = try PrivilegedHelperClient.decodeBooleanReply(
            false,
            errorMessage: nil,
            requiresSuccess: false
        )

        XCTAssertFalse(value)
    }
}
