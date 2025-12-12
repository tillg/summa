//
//  FingerprintService.swift
//  Summa
//
//  Service for generating visual fingerprints from screenshots using Vision framework
//

import Foundation
import Vision

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Service for generating visual fingerprints from screenshots
class FingerprintService {

    /// The Vision framework revision to use for fingerprint generation
    /// Using Revision 2 for better accuracy (requires iOS 17+)
    static let fingerprintRevision = VNGenerateImageFeaturePrintRequestRevision2

    /// Errors that can occur during fingerprint generation
    enum FingerprintError: Error {
        case invalidImageData
        case visionRequestFailed(Error)
        case noObservationReturned
        case fingerprintDataEncodingFailed
    }

    /// Generate a fingerprint from image data
    /// - Parameter imageData: The image data to generate fingerprint from
    /// - Returns: Tuple of (fingerprintData, revision) or throws error
    static func generateFingerprint(from imageData: Data) async throws -> (data: Data, revision: Int) {
        #if DEBUG
        let startTime = Date()
        #endif

        // Create platform image from data
        guard let image = PlatformImage.fromData(imageData) else {
            throw FingerprintError.invalidImageData
        }

        // Get CGImage from platform image
        #if os(iOS)
        guard let cgImage = image.cgImage else {
            throw FingerprintError.invalidImageData
        }
        #elseif os(macOS)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw FingerprintError.invalidImageData
        }
        #endif

        #if DEBUG
        let imageLoadTime = Date().timeIntervalSince(startTime)
        log("⏱️ Image load: \(String(format: "%.3f", imageLoadTime))s")
        #endif

        // Create Vision request handler
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // Create fingerprint request with explicit revision
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = fingerprintRevision

        #if DEBUG
        let visionStartTime = Date()
        #endif

        // Perform request
        do {
            try requestHandler.perform([request])
        } catch {
            throw FingerprintError.visionRequestFailed(error)
        }

        #if DEBUG
        let visionTime = Date().timeIntervalSince(visionStartTime)
        log("⏱️ Vision processing: \(String(format: "%.3f", visionTime))s")
        #endif

        // Get observation
        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw FingerprintError.noObservationReturned
        }

        // Encode observation to Data
        guard let encodedData = try? NSKeyedArchiver.archivedData(
            withRootObject: observation,
            requiringSecureCoding: true
        ) else {
            throw FingerprintError.fingerprintDataEncodingFailed
        }

        return (data: encodedData, revision: fingerprintRevision)
    }

    /// Decode fingerprint data back to VNFeaturePrintObservation
    /// - Parameter data: The encoded fingerprint data
    /// - Returns: VNFeaturePrintObservation or nil if decoding fails
    static func decodeFingerprint(from data: Data) -> VNFeaturePrintObservation? {
        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self,
            from: data
        )
    }

    /// Compute distance between two fingerprints
    /// - Parameters:
    ///   - fingerprint1: First fingerprint data
    ///   - fingerprint2: Second fingerprint data
    /// - Returns: Distance between fingerprints (0.0 = identical, higher = more different), or nil if comparison fails
    static func computeDistance(between fingerprint1: Data, and fingerprint2: Data) -> Float? {
        guard let obs1 = decodeFingerprint(from: fingerprint1),
              let obs2 = decodeFingerprint(from: fingerprint2) else {
            return nil
        }

        var distance: Float = 0
        do {
            try obs1.computeDistance(&distance, to: obs2)
            return distance
        } catch {
            return nil
        }
    }

}
