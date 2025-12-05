//
//  ScreenshotAnalysisServiceTests.swift
//  SummaTests
//
//  Priority 1: Tests for currency parsing and format assessment
//

import XCTest
@testable import Summa

final class ScreenshotAnalysisServiceTests: XCTestCase {

    var service: ScreenshotAnalysisService!

    @MainActor
    override func setUp() {
        super.setUp()
        service = ScreenshotAnalysisService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Currency Parsing Tests

    @MainActor
    func testParseCurrencyString_USFormat_ReturnsCorrectValue() {
        // US format with dollar sign and comma separator
        let result = service.parseCurrencyString("$1,234.56")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1234.56, accuracy: 0.01)
    }

    @MainActor
    func testParseCurrencyString_EuropeanFormat_ReturnsCorrectValue() {
        // European format with dot as thousands separator and comma as decimal
        let result = service.parseCurrencyString("1.234,56 EUR")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1234.56, accuracy: 0.01)
    }

    @MainActor
    func testParseCurrencyString_SwissFormat_ReturnsCorrectValue() {
        // Swiss format with apostrophe as thousands separator
        let result = service.parseCurrencyString("1'234.56 CHF")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1234.56, accuracy: 0.01)
    }

    @MainActor
    func testParseCurrencyString_EuroSymbol_ReturnsCorrectValue() {
        // European format with comma as decimal separator
        let result = service.parseCurrencyString("€1.234,56")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1234.56, accuracy: 0.01)
    }

    @MainActor
    func testParseCurrencyString_NoThousandsSeparator_ReturnsCorrectValue() {
        let result = service.parseCurrencyString("$1234")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1234.0, accuracy: 0.01)
    }

    @MainActor
    func testParseCurrencyString_OnlyCommas_ReturnsCorrectValue() {
        // With multiple commas, it's clearly a thousands separator
        let result = service.parseCurrencyString("$1,234,567")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1234567.0, accuracy: 0.01)
    }

    @MainActor
    func testParseCurrencyString_MultipleSeparators_ReturnsCorrectValue() {
        // Multiple thousands separators
        let result = service.parseCurrencyString("$1,234,567.89")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1234567.89, accuracy: 0.01)
    }

    @MainActor
    func testParseCurrencyString_InvalidText_ReturnsNil() {
        XCTAssertNil(service.parseCurrencyString("abc"))
        XCTAssertNil(service.parseCurrencyString(""))
    }

    @MainActor
    func testParseCurrencyString_MultipleDots_ValidEuropeanFormat_ReturnsValue() {
        // European format with dots as thousands separators
        let result = service.parseCurrencyString("1.234.567,89")
        // Current implementation parses European format correctly
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1234567.89, accuracy: 0.01)
    }

    @MainActor
    func testParseCurrencyString_ZeroValue_ReturnsZero() {
        let result = service.parseCurrencyString("$0.00")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 0.0, accuracy: 0.01)
    }

    @MainActor
    func testParseCurrencyString_VeryLargeNumber_ReturnsCorrectValue() {
        let result = service.parseCurrencyString("$999,999,999.99")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 999999999.99, accuracy: 0.01)
    }

    @MainActor
    func testParseCurrencyString_OutOfRangePositive_ReturnsNil() {
        // Test boundary: over 1 trillion
        let result = service.parseCurrencyString("$1,000,000,000,000.00")
        XCTAssertNil(result)
    }

    @MainActor
    func testParseCurrencyString_PoundSterling_ReturnsCorrectValue() {
        let result = service.parseCurrencyString("£1,234.56")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1234.56, accuracy: 0.01)
    }

    @MainActor
    func testParseCurrencyString_YenSymbol_ReturnsCorrectValue() {
        // Yen with multiple commas to clarify thousands separator
        let result = service.parseCurrencyString("¥1,234,567")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1234567.0, accuracy: 0.01)
    }

    @MainActor
    func testParseCurrencyString_DecimalOnly_ReturnsCorrectValue() {
        let result = service.parseCurrencyString("0.99")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 0.99, accuracy: 0.01)
    }

    // MARK: - Currency Symbol Detection Tests

    @MainActor
    func testDetectsCurrencySymbol_DollarSign_ReturnsTrue() {
        XCTAssertTrue(service.detectsCurrencySymbol("$1,234.56"))
    }

    @MainActor
    func testDetectsCurrencySymbol_EuroSymbol_ReturnsTrue() {
        XCTAssertTrue(service.detectsCurrencySymbol("€1.234,56"))
    }

    @MainActor
    func testDetectsCurrencySymbol_PoundSymbol_ReturnsTrue() {
        XCTAssertTrue(service.detectsCurrencySymbol("£1,234.56"))
    }

    @MainActor
    func testDetectsCurrencySymbol_CurrencyCode_ReturnsTrue() {
        XCTAssertTrue(service.detectsCurrencySymbol("1,234.56 USD"))
        XCTAssertTrue(service.detectsCurrencySymbol("EUR 1.234,56"))
        XCTAssertTrue(service.detectsCurrencySymbol("1'234.56 CHF"))
    }

    @MainActor
    func testDetectsCurrencySymbol_NoSymbol_ReturnsFalse() {
        XCTAssertFalse(service.detectsCurrencySymbol("1,234.56"))
    }

    @MainActor
    func testDetectsCurrencySymbol_YenSymbol_ReturnsTrue() {
        XCTAssertTrue(service.detectsCurrencySymbol("¥1,234"))
    }

    @MainActor
    func testDetectsCurrencySymbol_RupeeSymbol_ReturnsTrue() {
        XCTAssertTrue(service.detectsCurrencySymbol("₹1,234.56"))
    }

    // MARK: - Number Format Assessment Tests

    @MainActor
    func testAssessNumberFormat_WellFormattedWithSeparators_ReturnsHighScore() {
        // Should score high: has thousands separator, decimal, and reasonable length
        let score = service.assessNumberFormat("$1,234.56")
        XCTAssertGreaterThan(score, 0.9)
    }

    @MainActor
    func testAssessNumberFormat_NoSeparators_ReturnsLowerScore() {
        // Should score lower: no separators
        let score = service.assessNumberFormat("1234")
        XCTAssertLessThan(score, 0.5)
    }

    @MainActor
    func testAssessNumberFormat_OnlyThousandsSeparator_ReturnsMediumScore() {
        let score = service.assessNumberFormat("1,234")
        XCTAssertGreaterThan(score, 0.5)
        XCTAssertLessThanOrEqual(score, 1.0)
    }

    @MainActor
    func testAssessNumberFormat_OnlyDecimalSeparator_ReturnsMediumScore() {
        let score = service.assessNumberFormat("1234.56")
        XCTAssertGreaterThan(score, 0.3)
        XCTAssertLessThan(score, 0.8)
    }

    @MainActor
    func testAssessNumberFormat_VeryShortNumber_ReturnsLowerScore() {
        // Too short (< 4 digits)
        let score = service.assessNumberFormat("12")
        XCTAssertLessThan(score, 0.5)
    }

    @MainActor
    func testAssessNumberFormat_VeryLongNumber_ReturnsLowerScore() {
        // Too long (> 12 digits)
        let score = service.assessNumberFormat("12345678901234")
        XCTAssertLessThan(score, 0.5)
    }

    @MainActor
    func testAssessNumberFormat_ReasonableLength_ContributesToScore() {
        // 8 digits - should be in the sweet spot
        let score = service.assessNumberFormat("1,234.56")
        XCTAssertGreaterThan(score, 0.5)
    }

    @MainActor
    func testAssessNumberFormat_SwissApostrophe_CountsAsSeparator() {
        let score = service.assessNumberFormat("1'234.56")
        XCTAssertGreaterThan(score, 0.7)
    }

    @MainActor
    func testAssessNumberFormat_EuropeanFormat_HighScore() {
        let score = service.assessNumberFormat("1.234,56")
        XCTAssertGreaterThan(score, 0.7)
    }

    @MainActor
    func testAssessNumberFormat_EmptyString_ReturnsZero() {
        let score = service.assessNumberFormat("")
        XCTAssertEqual(score, 0.0)
    }

    @MainActor
    func testAssessNumberFormat_ScoreCappedAtOne() {
        // Even with all criteria met, score should not exceed 1.0
        let score = service.assessNumberFormat("$1,234,567.89")
        XCTAssertLessThanOrEqual(score, 1.0)
    }
}
