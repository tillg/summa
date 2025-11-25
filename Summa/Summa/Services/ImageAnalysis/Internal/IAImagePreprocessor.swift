//
//  IAImagePreprocessor.swift
//  Foundation Lab
//
//  Image optimization and resizing for Vision analysis
//

import Foundation
import CoreImage
import CoreGraphics

/// Service for preprocessing images before Vision analysis
final class IAImagePreprocessor: @unchecked Sendable {

    // MARK: - Configuration

    static let maxDimension: CGFloat = 4096

    // MARK: - Error Types

    enum PreprocessorError: LocalizedError {
        case invalidImageData
        case resizeFailed
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .invalidImageData:
                return "Invalid image data"
            case .resizeFailed:
                return "Failed to resize image"
            case .unsupportedFormat:
                return "Unsupported image format"
            }
        }
    }

    // MARK: - Preprocessing Methods

    /// Preprocesses an image from a file path, resizing if necessary
    func preprocess(imagePath: String) async throws -> URL {
        // Convert path to proper file URL
        let sourceURL: URL
        if imagePath.hasPrefix("/") || imagePath.hasPrefix("file://") {
            // Local file path
            if imagePath.hasPrefix("file://") {
                sourceURL = URL(fileURLWithPath: String(imagePath.dropFirst("file://".count)))
            } else {
                sourceURL = URL(fileURLWithPath: imagePath)
            }
        } else if let urlFromString = URL(string: imagePath), urlFromString.scheme != nil {
            // Valid URL with scheme
            sourceURL = urlFromString
        } else {
            // Fallback to file URL
            sourceURL = URL(fileURLWithPath: imagePath)
        }

        // Load image
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            throw PreprocessorError.invalidImageData
        }

        // Check if resizing is needed
        let maxCurrentDimension = max(width, height)
        if maxCurrentDimension <= Self.maxDimension {
            // No preprocessing needed
            return sourceURL
        }

        // Calculate new dimensions
        let scale = Self.maxDimension / maxCurrentDimension
        let newWidth = width * scale
        let newHeight = height * scale

        // Resize image
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw PreprocessorError.invalidImageData
        }

        let ciImage = CIImage(cgImage: cgImage)
        let resizedImage = try resizeImage(ciImage, to: CGSize(width: newWidth, height: newHeight))

        // Save to temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")

        try saveImage(resizedImage, to: tempURL)

        return tempURL
    }

    /// Resizes a CIImage to the specified size
    private func resizeImage(_ image: CIImage, to size: CGSize) throws -> CIImage {
        let scaleX = size.width / image.extent.width
        let scaleY = size.height / image.extent.height

        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        return image.transformed(by: transform)
    }

    /// Saves a CIImage to a file URL
    private func saveImage(_ image: CIImage, to url: URL) throws {
        let context = CIContext()
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        do {
            try context.writeJPEGRepresentation(
                of: image,
                to: url,
                colorSpace: colorSpace
            )
        } catch {
            throw PreprocessorError.resizeFailed
        }
    }

    /// Cleans up temporary files created during preprocessing
    func cleanupTemporaryFile(at url: URL) {
        guard url.path().contains(FileManager.default.temporaryDirectory.path()) else {
            return // Don't delete files outside temp directory
        }

        try? FileManager.default.removeItem(at: url)
    }
}
