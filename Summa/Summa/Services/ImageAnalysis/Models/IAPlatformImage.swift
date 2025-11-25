//
//  IAPlatformImage.swift
//  Foundation Lab
//
//  Cross-platform image type alias and extensions for ImageAnalysis
//

import Foundation

#if canImport(UIKit)
import UIKit
public typealias IAPlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias IAPlatformImage = NSImage
#endif

// For convenience when copying to other projects, you can use PlatformImage
// In this demo project, we use IAPlatformImage to avoid conflicts with Vision module

// MARK: - Platform Extensions

#if canImport(AppKit)
extension NSImage {
    /// Provides jpegData method for macOS compatibility with iOS UIImage
    func ia_jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmapImage.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionQuality]
        )
    }
}
#endif

#if canImport(UIKit)
import UIKit
import ImageIO

extension CGImagePropertyOrientation {
    static func ia_from(_ uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
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
}
#endif
