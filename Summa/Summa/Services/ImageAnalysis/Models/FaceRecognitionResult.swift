//
//  FaceRecognitionResult.swift
//  Foundation Lab
//
//  Face detection result
//

import Foundation
import CoreGraphics

/// Represents a detected face in an image
public struct FaceRecognitionResult: Identifiable {
    /// Unique identifier
    public let id: UUID

    /// Normalized bounding box in image coordinates (0.0-1.0)
    public let boundingBox: CGRect

    /// Facial landmark points (eyes, nose, mouth)
    public let landmarks: FacialLandmarks?

    /// Face capture quality score (0.0-1.0, where 1.0 is highest quality)
    public let captureQuality: Float?

    public init(
        id: UUID = UUID(),
        boundingBox: CGRect,
        landmarks: FacialLandmarks? = nil,
        captureQuality: Float? = nil
    ) {
        self.id = id
        self.boundingBox = boundingBox
        self.landmarks = landmarks
        self.captureQuality = captureQuality
    }
}

/// Facial landmark points
public struct FacialLandmarks {
    public let leftEye: CGPoint?
    public let rightEye: CGPoint?
    public let nose: CGPoint?
    public let mouth: CGPoint?

    public init(
        leftEye: CGPoint? = nil,
        rightEye: CGPoint? = nil,
        nose: CGPoint? = nil,
        mouth: CGPoint? = nil
    ) {
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.nose = nose
        self.mouth = mouth
    }
}

// MARK: - Convenience Properties

extension FaceRecognitionResult {
    /// Quality as a percentage (0-100)
    public var qualityPercent: Int? {
        guard let quality = captureQuality else { return nil }
        return Int(quality * 100)
    }

    /// Returns true if quality is above 80%
    public var isHighQuality: Bool {
        guard let quality = captureQuality else { return false }
        return quality >= 0.8
    }

    /// Returns true if landmarks are available
    public var hasLandmarks: Bool {
        landmarks != nil
    }
}
