//
//  SaveErrorHandlerTests.swift
//  SummaTests
//
//  Priority 1: Tests for SaveErrorHandler error message generation
//

import XCTest
@testable import Summa

final class SaveErrorHandlerTests: XCTestCase {

    // MARK: - User Message Tests

    func testUserMessage_NSCocoaErrorDomain_ReturnsGenericDatabaseMessage() {
        let error = NSError(
            domain: "NSCocoaErrorDomain",
            code: 134020,
            userInfo: [NSLocalizedDescriptionKey: "Some SwiftData error"]
        )

        let message = SaveErrorHandler.userMessage(for: error)

        XCTAssertEqual(message, "Unable to save changes to the database. Please try again.")
    }

    func testUserMessage_CKErrorNetworkUnavailable_ReturnsNetworkMessage() {
        let error = NSError(
            domain: "CKErrorDomain",
            code: 2, // CKErrorNetworkUnavailable
            userInfo: [NSLocalizedDescriptionKey: "Network is unavailable"]
        )

        let message = SaveErrorHandler.userMessage(for: error)

        XCTAssertEqual(message, "Network unavailable. Changes will sync when connection is restored.")
    }

    func testUserMessage_CKErrorServerRecordChanged_ReturnsConflictMessage() {
        let error = NSError(
            domain: "CKErrorDomain",
            code: 112, // CKErrorServerRecordChanged
            userInfo: [NSLocalizedDescriptionKey: "Server record changed"]
        )

        let message = SaveErrorHandler.userMessage(for: error)

        XCTAssertEqual(message, "This item was modified on another device. Please try again.")
    }

    func testUserMessage_CKErrorDomain_OtherCode_ReturnsGenericCloudKitMessage() {
        let error = NSError(
            domain: "CKErrorDomain",
            code: 999, // Some other CloudKit error
            userInfo: [NSLocalizedDescriptionKey: "Some CloudKit error"]
        )

        let message = SaveErrorHandler.userMessage(for: error)

        XCTAssertEqual(message, "iCloud sync error. Please check your internet connection.")
    }

    func testUserMessage_UnknownDomain_ReturnsGenericMessage() {
        let error = NSError(
            domain: "SomeCustomDomain",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "Custom error"]
        )

        let message = SaveErrorHandler.userMessage(for: error)

        XCTAssertEqual(message, "Unable to save changes. Please try again.")
    }

    func testUserMessage_SwiftError_ReturnsGenericMessage() {
        // Test with a Swift error type (not NSError)
        // When cast to NSError, it will have empty domain and fall through to default case
        struct CustomSwiftError: Error {}
        let error = CustomSwiftError()

        let message = SaveErrorHandler.userMessage(for: error)

        // Swift errors get bridged to NSError and fall through to the default case
        XCTAssertEqual(message, "Unable to save changes. Please try again.")
    }

    func testUserMessage_EmptyDomain_ReturnsGenericMessage() {
        let error = NSError(
            domain: "",
            code: 0,
            userInfo: nil
        )

        let message = SaveErrorHandler.userMessage(for: error)

        XCTAssertEqual(message, "Unable to save changes. Please try again.")
    }

    // MARK: - SaveResult Tests

    func testSaveResult_Success_IsSuccess() {
        let result = SaveErrorHandler.SaveResult.success

        XCTAssertTrue(result.isSuccess)
        XCTAssertNil(result.error)
    }

    func testSaveResult_Failure_IsNotSuccess() {
        let error = NSError(domain: "TestDomain", code: 1, userInfo: nil)
        let result = SaveErrorHandler.SaveResult.failure(error)

        XCTAssertFalse(result.isSuccess)
        XCTAssertNotNil(result.error)
    }

    func testSaveResult_Failure_ContainsError() {
        let expectedError = NSError(domain: "TestDomain", code: 42, userInfo: nil)
        let result = SaveErrorHandler.SaveResult.failure(expectedError)

        XCTAssertEqual((result.error as? NSError)?.domain, "TestDomain")
        XCTAssertEqual((result.error as? NSError)?.code, 42)
    }

    // MARK: - CloudKit Error Code Tests

    func testUserMessage_CKErrorQuotaExceeded_ReturnsCloudKitMessage() {
        // Code 25 - CKErrorQuotaExceeded
        let error = NSError(
            domain: "CKErrorDomain",
            code: 25,
            userInfo: nil
        )

        let message = SaveErrorHandler.userMessage(for: error)

        // Should return generic CloudKit message since this specific code isn't handled
        XCTAssertEqual(message, "iCloud sync error. Please check your internet connection.")
    }

    func testUserMessage_CKErrorZoneBusy_ReturnsCloudKitMessage() {
        // Code 23 - CKErrorZoneBusy
        let error = NSError(
            domain: "CKErrorDomain",
            code: 23,
            userInfo: nil
        )

        let message = SaveErrorHandler.userMessage(for: error)

        XCTAssertEqual(message, "iCloud sync error. Please check your internet connection.")
    }

    // MARK: - NSCocoaError Code Tests

    func testUserMessage_NSCocoaError_ValidationError_ReturnsDatabaseMessage() {
        // Code 1570 - NSValidationErrorMinimum
        let error = NSError(
            domain: "NSCocoaErrorDomain",
            code: 1570,
            userInfo: nil
        )

        let message = SaveErrorHandler.userMessage(for: error)

        XCTAssertEqual(message, "Unable to save changes to the database. Please try again.")
    }

    func testUserMessage_NSCocoaError_ManagedObjectConstraint_ReturnsDatabaseMessage() {
        // Code 133021 - NSManagedObjectConstraintMergeError
        let error = NSError(
            domain: "NSCocoaErrorDomain",
            code: 133021,
            userInfo: nil
        )

        let message = SaveErrorHandler.userMessage(for: error)

        XCTAssertEqual(message, "Unable to save changes to the database. Please try again.")
    }

    // MARK: - Edge Cases

    func testUserMessage_ErrorWithUserInfo_StillReturnsCorrectMessage() {
        let error = NSError(
            domain: "CKErrorDomain",
            code: 2,
            userInfo: [
                NSLocalizedDescriptionKey: "Network unavailable",
                "SomeCustomKey": "Some custom value"
            ]
        )

        let message = SaveErrorHandler.userMessage(for: error)

        // Should ignore userInfo and return based on domain and code
        XCTAssertEqual(message, "Network unavailable. Changes will sync when connection is restored.")
    }

    func testUserMessage_CKErrorCode_Zero_ReturnsGenericCloudKitMessage() {
        let error = NSError(
            domain: "CKErrorDomain",
            code: 0,
            userInfo: nil
        )

        let message = SaveErrorHandler.userMessage(for: error)

        XCTAssertEqual(message, "iCloud sync error. Please check your internet connection.")
    }

    func testUserMessage_CKErrorCode_Negative_ReturnsGenericCloudKitMessage() {
        let error = NSError(
            domain: "CKErrorDomain",
            code: -1,
            userInfo: nil
        )

        let message = SaveErrorHandler.userMessage(for: error)

        XCTAssertEqual(message, "iCloud sync error. Please check your internet connection.")
    }
}
