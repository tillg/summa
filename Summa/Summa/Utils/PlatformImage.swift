//
//  PlatformImage.swift
//  Summa
//
//  Cross-platform image type alias and extensions
//  Provides unified API for UIImage (iOS) and NSImage (macOS)
//

import Foundation

#if os(iOS)
import UIKit
public typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#endif

// MARK: - Cross-Platform Extensions

extension PlatformImage {

    // MARK: - JPEG Data Conversion

    // Note: On iOS, UIImage already has jpegData(compressionQuality:) method
    // We only need to add it for macOS

    /// Convert image to JPEG data with adaptive compression to meet size limit
    /// - Parameter maxSizeKB: Maximum size in kilobytes (default: 1024 KB)
    /// - Returns: Compressed JPEG data or nil if conversion fails
    func compressedJPEGData(maxSizeKB: Int = 1024) -> Data? {
        // Try different compression levels to stay under size limit
        let compressionLevels: [CGFloat] = [0.8, 0.6, 0.4, 0.2]
        let maxSizeBytes = maxSizeKB * 1024

        for compression in compressionLevels {
            if let data = self.jpegData(compressionQuality: compression),
               data.count <= maxSizeBytes {
                return data
            }
        }

        // If still too large, use lowest quality
        return self.jpegData(compressionQuality: 0.1)
    }

    // MARK: - Data Loading

    /// Create platform image from data
    /// - Parameter data: Image data (JPEG, PNG, etc.)
    /// - Returns: Platform image or nil if data is invalid
    static func fromData(_ data: Data) -> PlatformImage? {
        #if os(iOS)
        return UIImage(data: data)
        #elseif os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        // Ensure NSImage has proper size set from its representations
        if let rep = image.representations.first {
            image.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return image
        #endif
    }
}

// MARK: - macOS-Specific Extensions

#if os(macOS)
extension NSImage {
    /// Convert NSImage to JPEG data (equivalent to UIImage.jpegData on iOS)
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmapImage.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionQuality]
        )
    }

    /// Alias for jpegData to maintain compatibility with legacy code using ia_ prefix
    func ia_jpegData(compressionQuality: CGFloat) -> Data? {
        return jpegData(compressionQuality: compressionQuality)
    }
}
#endif

// MARK: - Platform-specific image properties

extension PlatformImage {
    /// Get the image orientation for Vision analysis
    /// Returns .up for macOS (no orientation metadata), actual orientation for iOS
    var imagePropertyOrientation: CGImagePropertyOrientation {
        #if os(iOS)
        return CGImagePropertyOrientation.from(self.imageOrientation)
        #else
        return .up
        #endif
    }
}

// MARK: - iOS-Specific Extensions

#if os(iOS)
import ImageIO

extension CGImagePropertyOrientation {
    /// Convert UIImage.Orientation to CGImagePropertyOrientation
    static func from(_ uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    /// Alias to maintain compatibility with legacy code using ia_ prefix
    static func ia_from(_ uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        return from(uiOrientation)
    }
}
#endif
