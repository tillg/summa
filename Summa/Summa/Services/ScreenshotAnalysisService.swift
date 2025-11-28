//
//  ScreenshotAnalysisService.swift
//  Summa
//
//  Service for analyzing screenshots and extracting monetary values
//

import Foundation
import Observation
import SwiftData

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Configurable weights for monetary value detection algorithm
struct DetectionWeights {
    let priorityWeight: Double = 0.4      // 40% - text size/prominence
    let confidenceWeight: Double = 0.3    // 30% - OCR confidence
    let currencySymbolWeight: Double = 0.2 // 20% - has currency symbol
    let formatWeight: Double = 0.1        // 10% - number formatting

    let minConfidence: Float = 0.75       // Minimum OCR confidence
    let maxPriority: Int = 3              // Only top 3 priority levels
    let minScore: Double = 0.6            // Minimum combined score
}

/// Service for analyzing screenshots and extracting monetary values
@Observable
@MainActor
final class ScreenshotAnalysisService {

    // MARK: - Properties

    private let imageAnalysis = ImageAnalysisService()
    private let weights = DetectionWeights()

    // MARK: - Public Methods

    /// Analyzes a snapshot's screenshot and extracts monetary value
    /// - Parameters:
    ///   - snapshot: The ValueSnapshot to analyze (must have sourceImage)
    ///   - modelContext: SwiftData model context for persistence
    func analyzeSnapshot(_ snapshot: ValueSnapshot, modelContext: ModelContext) async {
        #if DEBUG
        print("🔍 Starting analysis for snapshot: \(snapshot.date)")
        #endif

        // Verify we have screenshot data
        guard let imageData = snapshot.sourceImage else {
            #if DEBUG
            print("❌ No screenshot data available")
            #endif
            snapshot.analysisState = .analysisFailed
            snapshot.analysisError = "No screenshot data available"
            try? modelContext.save()
            return
        }

        #if DEBUG
        print("📸 Screenshot data found: \(imageData.count) bytes")
        #endif

        // Set analyzing state and record start time
        snapshot.analysisState = .analyzing
        snapshot.analysisError = nil
        try? modelContext.save()

        #if DEBUG
        print("✅ State set to ANALYZING, saved to database")
        #endif

        let analysisStartTime = Date()

        // Give UI time to update before continuing
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second for UI refresh

        #if DEBUG
        print("⏱️ DEBUG: Waiting 10 seconds to see analyzing state...")
        try? await Task.sleep(nanoseconds: 10_000_000_000)  // 10 second delay for UI feedback
        print("✅ DEBUG: Delay complete, performing analysis now")
        #endif

        do {
            // Convert Data to platform image
            #if canImport(UIKit)
            guard let image = UIImage(data: imageData) else {
                throw AnalysisError.invalidImageData
            }
            #else
            guard let image = NSImage(data: imageData) else {
                throw AnalysisError.invalidImageData
            }
            #endif

            // Perform Vision analysis
            await imageAnalysis.analyze(image: image)

            // Check for analysis errors
            if let error = imageAnalysis.error {
                throw AnalysisError.visionAnalysisFailed(error.localizedDescription)
            }

            // Get text results
            guard let textResults = imageAnalysis.analyzedImage?.textResults else {
                throw AnalysisError.noTextDetected
            }

            // Extract monetary value using multi-criteria algorithm
            let detectionResult = extractMonetaryValue(from: textResults)

            snapshot.analysisDate = Date()

            if let result = detectionResult {
                // Successfully extracted value
                snapshot.extractedValue = result.value
                snapshot.extractedText = result.text
                snapshot.analysisConfidence = result.confidence
                snapshot.value = result.value

                // Determine if analysis is full or partial
                if snapshot.series != nil {
                    snapshot.analysisState = .analysisCompleteFull
                    #if DEBUG
                    print("✅ Analysis complete (FULL): value=\(result.value), series=\(snapshot.series?.name ?? "unknown")")
                    #endif
                } else {
                    snapshot.analysisState = .analysisCompletePartial
                    #if DEBUG
                    print("⚠️ Analysis complete (PARTIAL): value=\(result.value), no series")
                    #endif
                }

            } else {
                // No monetary value found
                snapshot.analysisState = .analysisFailed
                snapshot.analysisError = "No monetary value detected in screenshot"
                #if DEBUG
                print("❌ Analysis FAILED: No monetary value detected")
                #endif
            }

            // Clear the image analysis results to free memory
            imageAnalysis.clear()

        } catch {
            // Handle analysis failure
            snapshot.analysisState = .analysisFailed
            snapshot.analysisError = error.localizedDescription
        }

        // Ensure minimum 3 seconds in "analyzing" state for UI feedback
        let elapsedTime = Date().timeIntervalSince(analysisStartTime)
        let minimumAnalysisTime: TimeInterval = 3.0

        if elapsedTime < minimumAnalysisTime {
            let remainingTime = minimumAnalysisTime - elapsedTime
            #if DEBUG
            print("⏱️ Analysis completed in \(String(format: "%.2f", elapsedTime))s, waiting \(String(format: "%.2f", remainingTime))s more for UI feedback...")
            #endif
            try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
        }

        // Save changes
        try? modelContext.save()
    }

    // MARK: - Private Methods

    /// Result of monetary value detection
    private struct DetectionResult {
        let value: Double
        let text: String
        let confidence: Float
        let score: Double
    }

    /// Extracts the most likely monetary value from text results
    private func extractMonetaryValue(from textResults: [TextRecognitionResult]) -> DetectionResult? {
        var candidates: [DetectionResult] = []

        // Scan all text results for monetary values
        for result in textResults {
            // Skip low confidence results
            guard result.confidence >= weights.minConfidence else { continue }

            // Skip low priority results (large priority number = low importance)
            guard result.priority <= weights.maxPriority else { continue }

            // Try to parse as monetary value
            guard let value = parseCurrencyString(result.text) else { continue }

            // Calculate combined score
            let score = calculateScore(for: result, value: value)

            // Skip results below minimum score threshold
            guard score >= weights.minScore else { continue }

            candidates.append(DetectionResult(
                value: value,
                text: result.text,
                confidence: result.confidence,
                score: score
            ))
        }

        // Return candidate with highest score
        return candidates.max(by: { $0.score < $1.score })
    }

    /// Calculates combined score for a monetary value candidate
    private func calculateScore(for result: TextRecognitionResult, value: Double) -> Double {
        var score = 0.0

        // 1. Priority Score (0-1, lower priority number = higher score)
        let priorityScore = result.priority <= weights.maxPriority
            ? max(0, 1.0 - (Double(result.priority - 1) / Double(weights.maxPriority)))
            : 0.0
        score += priorityScore * weights.priorityWeight

        // 2. Confidence Score (0-1)
        let confidenceScore = result.confidence >= weights.minConfidence
            ? Double(result.confidence)
            : 0.0
        score += confidenceScore * weights.confidenceWeight

        // 3. Currency Symbol Bonus (0-1)
        let hasCurrencySymbol = detectsCurrencySymbol(result.text)
        score += (hasCurrencySymbol ? 1.0 : 0.0) * weights.currencySymbolWeight

        // 4. Format Score (0-1)
        let formatScore = assessNumberFormat(result.text)
        score += formatScore * weights.formatWeight

        return score
    }

    /// Detects if text contains a currency symbol
    private func detectsCurrencySymbol(_ text: String) -> Bool {
        let currencyPattern = "[$€£¥₹₽¢₣₤₧₨₩₪₫₱₡₨₭₮₴₵₸₹₺₼₽₾₿]|\\b(USD|EUR|GBP|CHF|JPY|CNY|CAD|AUD|NZD)\\b"
        return text.range(of: currencyPattern, options: .regularExpression) != nil
    }

    /// Assesses the quality of number formatting
    private func assessNumberFormat(_ text: String) -> Double {
        var score = 0.0

        // Has thousands separator (comma, dot, or apostrophe)
        if text.contains(",") || text.contains("'") {
            score += 0.4
        }

        // Has decimal separator
        if text.contains(".") || text.contains(",") {
            score += 0.3
        }

        // Reasonable length (4-12 characters typical for monetary values)
        let digitCount = text.filter { $0.isNumber }.count
        if (4...12).contains(digitCount) {
            score += 0.3
        }

        return min(score, 1.0)
    }

    /// Parses a currency string to extract numeric value
    /// Handles multiple formats: US ($1,234.56), European (1.234,56), Swiss (1'234.56)
    private func parseCurrencyString(_ text: String) -> Double? {
        var cleaned = text

        // Remove currency symbols
        cleaned = cleaned.replacingOccurrences(of: "[$€£¥₹₽¢₣₤₧₨₩₪₫₱₡₨₭₮₴₵₸₹₺₼₽₾₿]", with: "", options: .regularExpression)

        // Remove common currency codes
        cleaned = cleaned.replacingOccurrences(of: "\\b(USD|EUR|GBP|CHF|JPY|CNY|CAD|AUD|NZD)\\b", with: "", options: .regularExpression)

        // Remove whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)

        // Detect decimal separator (last . or ,)
        let lastDot = cleaned.lastIndex(of: ".")
        let lastComma = cleaned.lastIndex(of: ",")

        // Handle European format (1.234,56) vs US format (1,234.56)
        if let comma = lastComma, let dot = lastDot {
            if comma > dot {
                // European format: remove dots (thousands), replace comma with dot
                cleaned = cleaned.replacingOccurrences(of: ".", with: "")
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            } else {
                // US format: just remove commas
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        } else if lastComma != nil {
            // Only comma present - check context
            let digitsBefore = cleaned.prefix(while: { $0.isNumber || $0 == "," || $0 == "'" })
            let commaCount = digitsBefore.filter { $0 == "," }.count

            if commaCount == 1 && cleaned.suffix(3).allSatisfy({ $0.isNumber }) {
                // Likely European decimal (e.g., "12,50")
                cleaned = cleaned.replacingOccurrences(of: "'", with: "")
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            } else {
                // Likely thousands separator (e.g., "1,234")
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        } else {
            // Only dots or no separators - remove apostrophes (Swiss thousands separator)
            cleaned = cleaned.replacingOccurrences(of: "'", with: "")
        }

        // Keep only digits, dot, and negative sign
        cleaned = cleaned.replacingOccurrences(of: "[^0-9.-]", with: "", options: .regularExpression)

        // Try to parse as Double
        guard let value = Double(cleaned) else { return nil }

        // Sanity check: reasonable range for monetary values
        guard value.isFinite && value >= 0 && value < 1_000_000_000_000 else { return nil }

        return value
    }
}

// MARK: - Error Types

enum AnalysisError: LocalizedError {
    case invalidImageData
    case visionAnalysisFailed(String)
    case noTextDetected

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data"
        case .visionAnalysisFailed(let message):
            return "Vision analysis failed: \(message)"
        case .noTextDetected:
            return "No text detected in screenshot"
        }
    }
}
