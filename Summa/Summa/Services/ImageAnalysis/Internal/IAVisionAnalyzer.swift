//
//  IAVisionAnalyzer.swift
//  Foundation Lab
//
//  Vision framework wrapper for ImageAnalysis service
//

import Foundation
import Vision
import CoreImage

/// Service class that wraps Apple Vision framework requests
final class IAVisionAnalyzer: @unchecked Sendable {

    // MARK: - Analysis Types

    enum AnalysisType: String, CaseIterable {
        case text
        case faces
        case objects
        case scenes
        case barcodes
        case saliency
    }

    // MARK: - Result Types

    struct AnalysisResults {
        var textResults: [TextResult] = []
        var faceResults: [FaceResult] = []
        var objectResults: [ObjectResult] = []
        var barcodeResults: [BarcodeResult] = []
        var saliencyResults: [SaliencyResult] = []
    }

    struct TextResult {
        let text: String
        let confidence: Float
        let boundingBox: CGRect
    }

    struct FaceResult {
        let boundingBox: CGRect
        let landmarks: FaceLandmarks?
        let captureQuality: Float?
    }

    struct FaceLandmarks {
        let leftEye: CGPoint?
        let rightEye: CGPoint?
        let nose: CGPoint?
        let mouth: CGPoint?
    }

    struct ObjectResult {
        let identifier: String
        let confidence: Float
    }

    struct BarcodeResult {
        let payload: String
        let symbology: String
        let boundingBox: CGRect
    }

    struct SaliencyResult {
        let boundingBoxes: [CGRect]
        let heatMap: CIImage?
    }

    // MARK: - Error Types

    enum IAVisionAnalyzerError: LocalizedError {
        case invalidImagePath
        case unsupportedImageFormat
        case visionRequestFailed(Error)
        case noImageData
        case memoryConstraint

        var errorDescription: String? {
            switch self {
            case .invalidImagePath:
                return "Invalid image file path"
            case .unsupportedImageFormat:
                return "Unsupported image format"
            case .visionRequestFailed(let error):
                return "Vision analysis failed: \(error.localizedDescription)"
            case .noImageData:
                return "Could not load image data from file"
            case .memoryConstraint:
                return "Image too large to process"
            }
        }
    }

    // MARK: - Analysis Methods

    /// Analyzes an image file with specified analysis types
    func analyze(
        imagePath: String,
        analysisTypes: [AnalysisType],
        includeConfidence: Bool = true,
        orientation: CGImagePropertyOrientation = .up
    ) async throws -> AnalysisResults {
        // Load and validate image - prefer file URL for local paths
        let url: URL
        if imagePath.hasPrefix("/") || imagePath.hasPrefix("file://") {
            // Local file path
            if imagePath.hasPrefix("file://") {
                url = URL(fileURLWithPath: String(imagePath.dropFirst("file://".count)))
            } else {
                url = URL(fileURLWithPath: imagePath)
            }
        } else if let urlFromString = URL(string: imagePath), urlFromString.scheme != nil {
            // Valid URL with scheme
            url = urlFromString
        } else {
            // Fallback to file URL
            url = URL(fileURLWithPath: imagePath)
        }

        guard let imageData = try? Data(contentsOf: url),
              let image = CIImage(data: imageData) else {
            throw IAVisionAnalyzerError.noImageData
        }

        // Create request handler with orientation
        let handler = VNImageRequestHandler(ciImage: image, orientation: orientation, options: [:])

        // Build requests array
        var requests: [VNRequest] = []

        if analysisTypes.contains(.text) {
            requests.append(VNRecognizeTextRequest())
        }

        if analysisTypes.contains(.faces) {
            requests.append(VNDetectFaceRectanglesRequest())
            requests.append(VNDetectFaceLandmarksRequest())
            requests.append(VNDetectFaceCaptureQualityRequest())
        }

        if analysisTypes.contains(.objects) || analysisTypes.contains(.scenes) {
            requests.append(VNClassifyImageRequest())
        }

        if analysisTypes.contains(.barcodes) {
            requests.append(VNDetectBarcodesRequest())
        }

        if analysisTypes.contains(.saliency) {
            requests.append(VNGenerateAttentionBasedSaliencyImageRequest())
        }

        // Perform requests
        do {
            try handler.perform(requests)
        } catch {
            throw IAVisionAnalyzerError.visionRequestFailed(error)
        }

        // Process results
        var results = AnalysisResults()

        for request in requests {
            switch request {
            case let textRequest as VNRecognizeTextRequest:
                results.textResults = processTextResults(textRequest.results)

            case let faceRequest as VNDetectFaceRectanglesRequest:
                results.faceResults = processFaceRectangles(faceRequest.results)

            case let landmarksRequest as VNDetectFaceLandmarksRequest:
                updateFaceLandmarks(&results.faceResults, landmarksRequest.results)

            case let qualityRequest as VNDetectFaceCaptureQualityRequest:
                updateFaceQuality(&results.faceResults, qualityRequest.results)

            case let classifyRequest as VNClassifyImageRequest:
                results.objectResults = processClassificationResults(classifyRequest.results)

            case let barcodeRequest as VNDetectBarcodesRequest:
                results.barcodeResults = processBarcodeResults(barcodeRequest.results)

            case let saliencyRequest as VNGenerateAttentionBasedSaliencyImageRequest:
                results.saliencyResults = processSaliencyResults(saliencyRequest.results)

            default:
                break
            }
        }

        return results
    }

    // MARK: - Result Processing

    private func processTextResults(_ observations: [VNRecognizedTextObservation]?) -> [TextResult] {
        guard let observations = observations else { return [] }

        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return TextResult(
                text: candidate.string,
                confidence: candidate.confidence,
                boundingBox: observation.boundingBox
            )
        }
    }

    private func processFaceRectangles(_ observations: [VNFaceObservation]?) -> [FaceResult] {
        guard let observations = observations else { return [] }

        return observations.map { observation in
            FaceResult(
                boundingBox: observation.boundingBox,
                landmarks: nil,
                captureQuality: nil
            )
        }
    }

    private func updateFaceLandmarks(_ faceResults: inout [FaceResult], _ observations: [VNFaceObservation]?) {
        guard let observations = observations else { return }

        for (index, observation) in observations.enumerated() {
            guard index < faceResults.count,
                  let landmarks = observation.landmarks else { continue }

            let faceLandmarks = FaceLandmarks(
                leftEye: landmarks.leftEye?.normalizedPoints.first,
                rightEye: landmarks.rightEye?.normalizedPoints.first,
                nose: landmarks.nose?.normalizedPoints.first,
                mouth: landmarks.innerLips?.normalizedPoints.first
            )

            faceResults[index] = FaceResult(
                boundingBox: faceResults[index].boundingBox,
                landmarks: faceLandmarks,
                captureQuality: faceResults[index].captureQuality
            )
        }
    }

    private func updateFaceQuality(_ faceResults: inout [FaceResult], _ observations: [VNFaceObservation]?) {
        guard let observations = observations else { return }

        for (index, observation) in observations.enumerated() {
            guard index < faceResults.count else { continue }

            faceResults[index] = FaceResult(
                boundingBox: faceResults[index].boundingBox,
                landmarks: faceResults[index].landmarks,
                captureQuality: observation.faceCaptureQuality
            )
        }
    }

    private func processClassificationResults(_ observations: [VNClassificationObservation]?) -> [ObjectResult] {
        guard let observations = observations else { return [] }

        // Filter for meaningful confidence (>10%)
        return observations
            .filter { $0.confidence > 0.1 }
            .map { ObjectResult(identifier: $0.identifier, confidence: $0.confidence) }
    }

    private func processBarcodeResults(_ observations: [VNBarcodeObservation]?) -> [BarcodeResult] {
        guard let observations = observations else { return [] }

        return observations.compactMap { observation in
            guard let payload = observation.payloadStringValue else { return nil }
            return BarcodeResult(
                payload: payload,
                symbology: observation.symbology.rawValue,
                boundingBox: observation.boundingBox
            )
        }
    }

    private func processSaliencyResults(_ observations: [VNSaliencyImageObservation]?) -> [SaliencyResult] {
        guard let observations = observations else { return [] }

        return observations.map { observation in
            let boundingBoxes = observation.salientObjects?.map { $0.boundingBox } ?? []
            let heatMap = CIImage(cvPixelBuffer: observation.pixelBuffer)
            return SaliencyResult(
                boundingBoxes: boundingBoxes,
                heatMap: heatMap
            )
        }
    }
}
