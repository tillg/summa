//
//  ImageMetadataExtractor.swift
//  Summa
//
//  Extracts timestamp metadata from images using EXIF/TIFF data
//

import Foundation
import ImageIO

struct ImageMetadataExtractor {
    /// Extracts date from image metadata, returns nil if not found
    /// Priority: EXIF DateTimeOriginal → TIFF DateTime → File creation/modification date
    static func extractDate(from url: URL) -> Date? {
        // 1. Try EXIF DateTimeOriginal (preferred - when photo was taken)
        if let exifDate = extractEXIFDate(from: url) {
            return exifDate
        }

        // 2. Try TIFF DateTime (fallback)
        if let tiffDate = extractTIFFDate(from: url) {
            return tiffDate
        }

        // 3. Try file creation/modification date
        if let fileDate = extractFileDate(from: url) {
            return fileDate
        }

        return nil
    }

    /// Extracts date from image metadata with fallback to Date.now
    static func extractDateWithFallback(from url: URL) -> Date {
        return extractDate(from: url) ?? Date.now
    }

    // MARK: - Private Extraction Methods

    private static func extractEXIFDate(from url: URL) -> Date? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
              let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String else {
            return nil
        }
        return parseEXIFDate(dateString)
    }

    private static func extractTIFFDate(from url: URL) -> Date? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
              let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
              let dateString = tiffDict[kCGImagePropertyTIFFDateTime as String] as? String else {
            return nil
        }
        return parseEXIFDate(dateString)
    }

    private static func extractFileDate(from url: URL) -> Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            // Prefer creation date, fallback to modification date
            return attributes[.creationDate] as? Date ?? attributes[.modificationDate] as? Date
        } catch {
            return nil
        }
    }

    private static func parseEXIFDate(_ dateString: String) -> Date? {
        // EXIF format: "yyyy:MM:dd HH:mm:ss"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current  // Use device timezone
        return formatter.date(from: dateString)
    }
}
