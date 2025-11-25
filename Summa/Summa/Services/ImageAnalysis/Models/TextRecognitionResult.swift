//
//  TextRecognitionResult.swift
//  Foundation Lab
//
//  Text recognition result with importance scoring
//

import Foundation
import CoreGraphics

/// Represents recognized text in an image with importance metadata
public struct TextRecognitionResult: Identifiable {
    /// Unique identifier
    public let id: UUID

    /// The recognized text string
    public let text: String

    /// Recognition confidence (0.0-1.0, where 1.0 is highest confidence)
    public let confidence: Float

    /// Visual importance priority (1 = highest, based on text size)
    public let priority: Int

    /// Normalized bounding box in image coordinates (0.0-1.0)
    /// Origin is bottom-left in Vision coordinate system
    public let boundingBox: CGRect

    /// Estimated point size of the text
    public let estimatedPointSize: CGFloat?

    /// Height of text bounding box in pixels
    public let heightInPixels: CGFloat?

    public init(
        id: UUID = UUID(),
        text: String,
        confidence: Float,
        priority: Int,
        boundingBox: CGRect,
        estimatedPointSize: CGFloat? = nil,
        heightInPixels: CGFloat? = nil
    ) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.priority = priority
        self.boundingBox = boundingBox
        self.estimatedPointSize = estimatedPointSize
        self.heightInPixels = heightInPixels
    }
}

// MARK: - Convenience Properties

extension TextRecognitionResult {
    /// Confidence as a percentage (0-100)
    public var confidencePercent: Int {
        Int(confidence * 100)
    }

    /// Returns true if confidence is above 80%
    public var isHighConfidence: Bool {
        confidence >= 0.8
    }

    /// Priority category description
    public var priorityDescription: String {
        switch priority {
        case 1: return "Highest"
        case 2: return "High"
        case 3: return "Medium"
        default: return "Low"
        }
    }
}
