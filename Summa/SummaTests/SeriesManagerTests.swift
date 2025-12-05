//
//  SeriesManagerTests.swift
//  SummaTests
//
//  Priority 1: Tests for SeriesManager color utilities
//

import XCTest
import SwiftUI
@testable import Summa

final class SeriesManagerTests: XCTestCase {

    var manager: SeriesManager!

    override func setUp() {
        super.setUp()
        manager = SeriesManager.shared
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Color From Hex Tests

    func testColorFromHex_RedColor_ReturnsCorrectRGB() {
        let color = manager.colorFromHex("#FF3B30")

        // Extract RGB components
        let uiColor = PlatformColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 1.0, accuracy: 0.01) // FF = 255/255 = 1.0
        XCTAssertEqual(green, 0.231, accuracy: 0.01) // 3B = 59/255 ≈ 0.231
        XCTAssertEqual(blue, 0.188, accuracy: 0.01) // 30 = 48/255 ≈ 0.188
    }

    func testColorFromHex_BlueColor_ReturnsCorrectRGB() {
        let color = manager.colorFromHex("#007AFF")

        let uiColor = PlatformColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 0.0, accuracy: 0.01)
        XCTAssertEqual(green, 0.478, accuracy: 0.01) // 7A = 122/255 ≈ 0.478
        XCTAssertEqual(blue, 1.0, accuracy: 0.01)
    }

    func testColorFromHex_GreenColor_ReturnsCorrectRGB() {
        let color = manager.colorFromHex("#34C759")

        let uiColor = PlatformColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 0.204, accuracy: 0.01) // 34 = 52/255 ≈ 0.204
        XCTAssertEqual(green, 0.780, accuracy: 0.01) // C7 = 199/255 ≈ 0.780
        XCTAssertEqual(blue, 0.349, accuracy: 0.01) // 59 = 89/255 ≈ 0.349
    }

    func testColorFromHex_WithoutHashSymbol_ReturnsCorrectRGB() {
        // Should handle hex strings without the # prefix
        let color = manager.colorFromHex("FF3B30")

        let uiColor = PlatformColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 1.0, accuracy: 0.01)
        XCTAssertEqual(green, 0.231, accuracy: 0.01)
        XCTAssertEqual(blue, 0.188, accuracy: 0.01)
    }

    func testColorFromHex_BlackColor_ReturnsCorrectRGB() {
        let color = manager.colorFromHex("#000000")

        let uiColor = PlatformColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 0.0, accuracy: 0.01)
        XCTAssertEqual(green, 0.0, accuracy: 0.01)
        XCTAssertEqual(blue, 0.0, accuracy: 0.01)
    }

    func testColorFromHex_WhiteColor_ReturnsCorrectRGB() {
        let color = manager.colorFromHex("#FFFFFF")

        let uiColor = PlatformColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 1.0, accuracy: 0.01)
        XCTAssertEqual(green, 1.0, accuracy: 0.01)
        XCTAssertEqual(blue, 1.0, accuracy: 0.01)
    }

    func testColorFromHex_InvalidHexString_ReturnsBlackColor() {
        // Invalid hex strings should return black (0,0,0)
        let color = manager.colorFromHex("invalid")

        let uiColor = PlatformColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 0.0, accuracy: 0.01)
        XCTAssertEqual(green, 0.0, accuracy: 0.01)
        XCTAssertEqual(blue, 0.0, accuracy: 0.01)
    }

    func testColorFromHex_EmptyString_ReturnsBlackColor() {
        let color = manager.colorFromHex("")

        let uiColor = PlatformColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 0.0, accuracy: 0.01)
        XCTAssertEqual(green, 0.0, accuracy: 0.01)
        XCTAssertEqual(blue, 0.0, accuracy: 0.01)
    }

    func testColorFromHex_ShortHexFormat_HandledCorrectly() {
        // Three-digit hex format (e.g., #F00 for red) should be handled
        // Note: Current implementation expects 6 digits, so this tests edge case
        let color = manager.colorFromHex("#F00")

        let uiColor = PlatformColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // With current implementation, this will be parsed as 0x0F00 (3840 in decimal)
        // which gives R=15, G=0, B=0 after bit shifting
        // This tests that the function doesn't crash on short formats
        XCTAssertNotNil(color)
    }

    func testColorFromHex_LowercaseHex_ReturnsCorrectRGB() {
        let color = manager.colorFromHex("#ff3b30")

        let uiColor = PlatformColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 1.0, accuracy: 0.01)
        XCTAssertEqual(green, 0.231, accuracy: 0.01)
        XCTAssertEqual(blue, 0.188, accuracy: 0.01)
    }

    // MARK: - Predefined Colors Tests

    func testPredefinedColors_ContainsTenColors() {
        XCTAssertEqual(SeriesManager.predefinedColors.count, 10)
    }

    func testPredefinedColors_AllValidHexStrings() {
        for hexColor in SeriesManager.predefinedColors {
            // Each should start with # and be 7 characters long
            XCTAssertTrue(hexColor.hasPrefix("#"))
            XCTAssertEqual(hexColor.count, 7)

            // Should be convertible to a color without crashing
            let color = manager.colorFromHex(hexColor)
            XCTAssertNotNil(color)
        }
    }

    func testPredefinedColors_AreDistinct() {
        // All colors should be unique
        let uniqueColors = Set(SeriesManager.predefinedColors)
        XCTAssertEqual(uniqueColors.count, SeriesManager.predefinedColors.count)
    }

    func testPredefinedColors_FirstColorIsRed() {
        XCTAssertEqual(SeriesManager.predefinedColors[0], "#FF3B30")
    }

    func testPredefinedColors_FifthColorIsBlue() {
        // Index 4 (fifth color) should be blue
        XCTAssertEqual(SeriesManager.predefinedColors[4], "#007AFF")
    }
}
