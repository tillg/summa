//
//  ObjectRecognitionResult.swift
//  Foundation Lab
//
//  Object classification result
//

import Foundation

/// Represents a classified object or scene in an image
public struct ObjectRecognitionResult: Identifiable {
    /// Unique identifier
    public let id: UUID

    /// Object or scene identifier (e.g., "indoor_scene", "dog", "food")
    public let identifier: String

    /// Classification confidence (0.0-1.0, where 1.0 is highest confidence)
    public let confidence: Float

    public init(
        id: UUID = UUID(),
        identifier: String,
        confidence: Float
    ) {
        self.id = id
        self.identifier = identifier
        self.confidence = confidence
    }
}

// MARK: - Convenience Properties

extension ObjectRecognitionResult {
    /// Confidence as a percentage (0-100)
    public var confidencePercent: Int {
        Int(confidence * 100)
    }

    /// Human-readable display name
    /// Converts "indoor_scene" to "Indoor Scene"
    public var displayName: String {
        identifier
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    /// Returns true if confidence is above 50%
    public var isHighConfidence: Bool {
        confidence >= 0.5
    }
}
