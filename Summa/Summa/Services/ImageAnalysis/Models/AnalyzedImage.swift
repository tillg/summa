//
//  AnalyzedImage.swift
//  Foundation Lab
//
//  Container for image analysis results
//

import Foundation
import CoreGraphics

/// Contains the complete analysis results for an image
public struct AnalyzedImage {
    /// The original image that was analyzed
    public let originalImage: IAPlatformImage

    /// Text recognition results with priority scoring
    public let textResults: [TextRecognitionResult]

    /// Face detection results
    public let faceResults: [FaceRecognitionResult]

    /// Object classification results
    public let objectResults: [ObjectRecognitionResult]

    /// Size of the analyzed image in pixels
    public let imageSize: CGSize

    public init(
        originalImage: IAPlatformImage,
        textResults: [TextRecognitionResult],
        faceResults: [FaceRecognitionResult],
        objectResults: [ObjectRecognitionResult],
        imageSize: CGSize
    ) {
        self.originalImage = originalImage
        self.textResults = textResults
        self.faceResults = faceResults
        self.objectResults = objectResults
        self.imageSize = imageSize
    }
}

// MARK: - Convenience Properties

extension AnalyzedImage {
    /// Returns true if any analysis results were found
    public var hasResults: Bool {
        !textResults.isEmpty || !faceResults.isEmpty || !objectResults.isEmpty
    }

    /// Total count of all detected items
    public var totalResultCount: Int {
        textResults.count + faceResults.count + objectResults.count
    }

    /// Text results sorted by priority (1 = highest)
    public var textResultsByPriority: [TextRecognitionResult] {
        textResults.sorted { $0.priority < $1.priority }
    }
}
