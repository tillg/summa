//
//  ImagePicker.swift
//  Summa
//
//  Created for screenshot attachment functionality
//

import SwiftUI
import PhotosUI

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif

// Helper to convert images to Data
extension PlatformImage {
    func compressedJPEGData(maxSizeKB: Int = 1024) -> Data? {
        // Try different compression levels to stay under size limit
        let compressionLevels: [CGFloat] = [0.8, 0.6, 0.4, 0.2]
        let maxSizeBytes = maxSizeKB * 1024

        #if os(iOS)
        for compression in compressionLevels {
            if let data = self.jpegData(compressionQuality: compression),
               data.count <= maxSizeBytes {
                return data
            }
        }
        // If still too large, use lowest quality
        return self.jpegData(compressionQuality: 0.1)

        #elseif os(macOS)
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

        for compression in compressionLevels {
            if let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: compression]),
               data.count <= maxSizeBytes {
                return data
            }
        }
        // If still too large, use lowest quality
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.1])
        #endif
    }

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
