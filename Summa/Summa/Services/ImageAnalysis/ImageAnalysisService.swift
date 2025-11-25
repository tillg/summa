//
//  ImageAnalysisService.swift
//  Foundation Lab
//
//  Main service for analyzing images using Vision framework
//

import Foundation
import Observation
import ImageIO

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Service for analyzing images with text recognition, face detection, and object classification
@Observable
public final class ImageAnalysisService {

    // MARK: - Public Properties

    /// The current analyzed image with all results
    public private(set) var analyzedImage: AnalyzedImage?

    /// Indicates whether an analysis is currently in progress
    public private(set) var isAnalyzing = false

    /// The most recent error, if any
    public private(set) var error: Error?

    // MARK: - Internal Services

    private let visionAnalyzer = IAVisionAnalyzer()
    private let fontSizeAnalyzer = IAFontSizeAnalyzer()
    private let preprocessor = IAImagePreprocessor()

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Analyzes an image and updates the analyzedImage property
    /// - Parameter image: The image to analyze (UIImage on iOS, NSImage on macOS)
    @MainActor
    public func analyze(image: IAPlatformImage) async {
        isAnalyzing = true
        error = nil
        analyzedImage = nil

        do {
            // Save image to temporary file
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("jpg")

            let jpegData: Data?
            #if canImport(UIKit)
            jpegData = image.jpegData(compressionQuality: 0.9)
            #else
            jpegData = image.ia_jpegData(compressionQuality: 0.9)
            #endif

            guard let imageData = jpegData else {
                throw ImageAnalysisError.imageProcessingFailed("Failed to convert image to JPEG")
            }

            try imageData.write(to: tempURL)

            // Get image orientation
            #if canImport(UIKit)
            let orientation = CGImagePropertyOrientation.ia_from(image.imageOrientation)
            #else
            let orientation = CGImagePropertyOrientation.up
            #endif

            // Preprocess image
            let preprocessedURL = try await preprocessor.preprocess(imagePath: tempURL.path())

            // Perform Vision analysis
            let visionResults = try await visionAnalyzer.analyze(
                imagePath: preprocessedURL.path(),
                analysisTypes: [.text, .faces, .objects],
                includeConfidence: true,
                orientation: orientation
            )

            // Get image size
            #if canImport(UIKit)
            let imageSize = image.size
            #else
            let imageSize = image.size
            #endif

            // Convert to public API models
            let analyzed = try convertToAnalyzedImage(
                image: image,
                visionResults: visionResults,
                imageSize: imageSize
            )

            analyzedImage = analyzed

            // Cleanup temp files
            if preprocessedURL != tempURL {
                preprocessor.cleanupTemporaryFile(at: preprocessedURL)
            }
            preprocessor.cleanupTemporaryFile(at: tempURL)

        } catch {
            self.error = error
        }

        isAnalyzing = false
    }

    /// Clears the current analysis results
    public func clear() {
        analyzedImage = nil
        error = nil
    }

    // MARK: - Private Helper Methods

    private func convertToAnalyzedImage(
        image: IAPlatformImage,
        visionResults: IAVisionAnalyzer.AnalysisResults,
        imageSize: CGSize
    ) throws -> AnalyzedImage {
        // Convert text results with priority scoring
        let textResults = convertTextResults(
            visionResults.textResults,
            imageSize: imageSize
        )

        // Convert face results
        let faceResults = visionResults.faceResults.map { result in
            let landmarks = result.landmarks.map { visionLandmarks in
                FacialLandmarks(
                    leftEye: visionLandmarks.leftEye,
                    rightEye: visionLandmarks.rightEye,
                    nose: visionLandmarks.nose,
                    mouth: visionLandmarks.mouth
                )
            }

            return FaceRecognitionResult(
                boundingBox: result.boundingBox,
                landmarks: landmarks,
                captureQuality: result.captureQuality
            )
        }

        // Convert object results
        let objectResults = visionResults.objectResults.map { result in
            ObjectRecognitionResult(
                identifier: result.identifier,
                confidence: result.confidence
            )
        }

        return AnalyzedImage(
            originalImage: image,
            textResults: textResults,
            faceResults: faceResults,
            objectResults: objectResults,
            imageSize: imageSize
        )
    }

    private func convertTextResults(
        _ visionTextResults: [IAVisionAnalyzer.TextResult],
        imageSize: CGSize
    ) -> [TextRecognitionResult] {
        guard !visionTextResults.isEmpty else { return [] }

        // Convert to internal format for priority analysis
        let textFeatures = visionTextResults.map { result in
            IAFontSizeAnalyzer.InternalTextFeature(
                text: result.text,
                confidence: result.confidence,
                boundingBox: result.boundingBox
            )
        }

        // Analyze importance/priority
        let importanceResults = fontSizeAnalyzer.analyzeImportance(
            textFeatures: textFeatures,
            imageSize: imageSize
        )

        // Convert to public API model
        return importanceResults.map { importance in
            TextRecognitionResult(
                text: importance.text,
                confidence: importance.confidence,
                priority: importance.priority,
                boundingBox: importance.boundingBox,
                estimatedPointSize: importance.estimatedPointSize,
                heightInPixels: importance.heightInPixels
            )
        }
    }
}

// MARK: - Error Types

enum ImageAnalysisError: LocalizedError {
    case imageProcessingFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed(let message):
            return "Image processing failed: \(message)"
        }
    }
}
