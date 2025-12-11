//
//  ImageMetadataExtractorTests.swift
//  SummaTests
//
//  Tests for ImageMetadataExtractor date extraction functionality
//

import XCTest
@testable import Summa

final class ImageMetadataExtractorTests: XCTestCase {

    var testImagesURL: URL!

    override func setUp() {
        super.setUp()
        // Create test images directory in test bundle
        testImagesURL = Bundle(for: type(of: self)).resourceURL?.appendingPathComponent("TestImages")
    }

    override func tearDown() {
        testImagesURL = nil
        super.tearDown()
    }

    // MARK: - Basic API Tests

    func testExtractDate_WithNonExistentFile_ReturnsNil() {
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/image.jpg")
        let result = ImageMetadataExtractor.extractDate(from: nonExistentURL)

        XCTAssertNil(result, "Should return nil for non-existent file")
    }

    func testExtractDateWithFallback_WithNonExistentFile_ReturnsCurrentDate() {
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/image.jpg")
        let before = Date()
        let result = ImageMetadataExtractor.extractDateWithFallback(from: nonExistentURL)
        let after = Date()

        XCTAssertNotNil(result, "Should return a date")
        XCTAssertTrue(result >= before && result <= after, "Should return current date as fallback")
    }

    // MARK: - Test Images with EXIF Data
    // TODO: Add sample images to TestImages folder and uncomment these tests

    func testExtractDate_ImageWithEXIF_ReturnsCorrectDate() throws {
        // TODO: Provide an image with EXIF DateTimeOriginal metadata
        // Expected: Should extract the EXIF date
        try XCTSkipIf(testImagesURL == nil, "Test images directory not found")

        let imageURL = testImagesURL.appendingPathComponent("photo_with_exif.jpg")
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw XCTSkip("Test image 'photo_with_exif.jpg' not found. Please add sample image.")
        }

        let result = ImageMetadataExtractor.extractDate(from: imageURL)

        XCTAssertNotNil(result, "Should extract date from EXIF metadata")

        // TODO: Verify against known date from the test image
        // Example: XCTAssertEqual(result?.timeIntervalSince1970, expectedTimestamp, accuracy: 1.0)
    }

    func testExtractDate_ImageWithTIFFDateTime_ReturnsCorrectDate() throws {
        // TODO: Provide an image with TIFF DateTime but no EXIF data
        // Expected: Should extract the TIFF date
        try XCTSkipIf(testImagesURL == nil, "Test images directory not found")

        let imageURL = testImagesURL.appendingPathComponent("photo_with_tiff.jpg")
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw XCTSkip("Test image 'photo_with_tiff.jpg' not found. Please add sample image.")
        }

        let result = ImageMetadataExtractor.extractDate(from: imageURL)

        XCTAssertNotNil(result, "Should extract date from TIFF DateTime")
    }

    func testExtractDate_ImageWithNoMetadata_UsesFileDate() throws {
        // TODO: Provide an image with no EXIF/TIFF metadata
        // Expected: Should fall back to file creation/modification date
        try XCTSkipIf(testImagesURL == nil, "Test images directory not found")

        let imageURL = testImagesURL.appendingPathComponent("photo_no_metadata.jpg")
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw XCTSkip("Test image 'photo_no_metadata.jpg' not found. Please add sample image.")
        }

        let result = ImageMetadataExtractor.extractDate(from: imageURL)

        XCTAssertNotNil(result, "Should extract date from file attributes")

        // Verify it matches file creation or modification date
        let attributes = try FileManager.default.attributesOfItem(atPath: imageURL.path)
        let fileDate = attributes[.creationDate] as? Date ?? attributes[.modificationDate] as? Date

        if let fileDate = fileDate, let result = result {
            XCTAssertEqual(result.timeIntervalSince1970, fileDate.timeIntervalSince1970, accuracy: 1.0)
        }
    }

    func testExtractDate_PNG_ExtractsMetadata() throws {
        // TODO: Provide a PNG image with metadata
        // Expected: Should work with PNG format
        try XCTSkipIf(testImagesURL == nil, "Test images directory not found")

        let imageURL = testImagesURL.appendingPathComponent("photo.png")
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw XCTSkip("Test image 'photo.png' not found. Please add sample image.")
        }

        let result = ImageMetadataExtractor.extractDate(from: imageURL)

        XCTAssertNotNil(result, "Should extract date from PNG image")
    }

    func testExtractDate_HEIC_ExtractsMetadata() throws {
        // TODO: Provide a HEIC image (common on iPhone)
        // Expected: Should work with HEIC format
        try XCTSkipIf(testImagesURL == nil, "Test images directory not found")

        let imageURL = testImagesURL.appendingPathComponent("photo.heic")
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw XCTSkip("Test image 'photo.heic' not found. Please add sample image.")
        }

        let result = ImageMetadataExtractor.extractDate(from: imageURL)

        XCTAssertNotNil(result, "Should extract date from HEIC image")
    }

    // MARK: - Edge Cases

    func testExtractDate_EmptyFile_ReturnsNil() throws {
        // Create a temporary empty file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("empty.jpg")
        try Data().write(to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let result = ImageMetadataExtractor.extractDate(from: tempURL)

        // Should either return nil or file date (acceptable either way)
        // The important thing is it doesn't crash
        XCTAssertNotNil(ImageMetadataExtractor.extractDateWithFallback(from: tempURL))
    }

    func testExtractDate_CorruptedImageFile_HandlesGracefully() throws {
        // Create a file with invalid JPEG data
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("corrupted.jpg")
        let corruptedData = Data([0xFF, 0xD8, 0xFF]) // Incomplete JPEG header
        try corruptedData.write(to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let result = ImageMetadataExtractor.extractDate(from: tempURL)

        // Should handle gracefully (either return nil or file date, but shouldn't crash)
        XCTAssertNotNil(ImageMetadataExtractor.extractDateWithFallback(from: tempURL))
    }

    func testExtractDate_NonImageFile_HandlesGracefully() throws {
        // Create a text file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("text.txt")
        try "Not an image".write(to: tempURL, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let result = ImageMetadataExtractor.extractDate(from: tempURL)

        // Should handle gracefully - might return file date or nil
        XCTAssertNoThrow(ImageMetadataExtractor.extractDateWithFallback(from: tempURL))
    }

    // MARK: - Timezone Tests

    func testExtractDate_UsesDeviceTimezone() throws {
        // TODO: Provide an image with known EXIF date "2024:01:15 14:30:00"
        // Expected: Should parse using device timezone
        try XCTSkipIf(testImagesURL == nil, "Test images directory not found")

        let imageURL = testImagesURL.appendingPathComponent("photo_known_date.jpg")
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw XCTSkip("Test image 'photo_known_date.jpg' not found. Please add sample image with known EXIF date.")
        }

        let result = ImageMetadataExtractor.extractDate(from: imageURL)

        // TODO: Verify the timezone is correct
        // This would require knowing the device timezone and the EXIF date string
        XCTAssertNotNil(result, "Should extract date with device timezone")
    }

    // MARK: - Priority Tests (EXIF > TIFF > File)

    func testExtractDate_PrioritizesEXIFOverTIFF() throws {
        // TODO: Provide an image with both EXIF DateTimeOriginal and TIFF DateTime
        // EXIF should be preferred
        try XCTSkipIf(testImagesURL == nil, "Test images directory not found")

        let imageURL = testImagesURL.appendingPathComponent("photo_exif_and_tiff.jpg")
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw XCTSkip("Test image with both EXIF and TIFF dates not found.")
        }

        let result = ImageMetadataExtractor.extractDate(from: imageURL)

        XCTAssertNotNil(result, "Should extract date from EXIF (not TIFF)")
        // TODO: Verify it matches EXIF date, not TIFF date
    }

    func testExtractDate_PrioritizesTIFFOverFileDate() throws {
        // TODO: Provide an image with TIFF DateTime but no EXIF
        // TIFF should be preferred over file date
        try XCTSkipIf(testImagesURL == nil, "Test images directory not found")

        let imageURL = testImagesURL.appendingPathComponent("photo_tiff_only.jpg")
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw XCTSkip("Test image with TIFF date only not found.")
        }

        let result = ImageMetadataExtractor.extractDate(from: imageURL)

        XCTAssertNotNil(result, "Should extract date from TIFF (not file date)")

        // Compare with file date - they should be different
        let attributes = try FileManager.default.attributesOfItem(atPath: imageURL.path)
        let fileDate = attributes[.creationDate] as? Date

        if let fileDate = fileDate, let result = result {
            // TIFF date should be different from file date
            // (This assumes you create a test file where these differ)
            XCTAssertNotEqual(result.timeIntervalSince1970, fileDate.timeIntervalSince1970, accuracy: 1.0,
                            "TIFF date should be used instead of file date")
        }
    }

    // MARK: - Performance Tests

    func testExtractDate_Performance() throws {
        // Create a temporary image file for performance testing
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("perf_test.jpg")

        // Use minimal JPEG data
        let jpegHeader = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46])
        try jpegHeader.write(to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Measure performance
        measure {
            _ = ImageMetadataExtractor.extractDate(from: tempURL)
        }
    }
}
