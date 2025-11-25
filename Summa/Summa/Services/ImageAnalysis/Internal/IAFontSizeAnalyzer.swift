//
//  IAFontSizeAnalyzer.swift
//  Foundation Lab
//
//  Analyzes text elements in images to calculate importance scores
//

import Foundation
import CoreGraphics

/// Service class that calculates text importance based on visual prominence
final class IAFontSizeAnalyzer {

    // MARK: - Analysis Result

    struct TextImportance {
        let text: String
        let confidence: Float
        let boundingBox: CGRect
        let priority: Int  // 1 = highest importance
        let estimatedPointSize: CGFloat
        let heightInPixels: CGFloat
    }

    // MARK: - Internal Model

    struct InternalTextFeature {
        let text: String
        let confidence: Float
        let boundingBox: CGRect
    }

    // MARK: - Analysis Methods

    /// Analyzes text features and returns them ranked by importance
    func analyzeImportance(
        textFeatures: [InternalTextFeature],
        imageSize: CGSize
    ) -> [TextImportance] {
        guard !textFeatures.isEmpty else { return [] }

        // Calculate height scores for all text elements
        let textWithScores = textFeatures.map { feature -> (feature: InternalTextFeature, heightScore: CGFloat) in
            let heightInPixels = feature.boundingBox.height * imageSize.height
            return (feature, heightScore: heightInPixels)
        }

        // Sort by height (descending)
        let sorted = textWithScores.sorted { $0.heightScore > $1.heightScore }

        // Assign priorities (handling ties)
        var results: [TextImportance] = []
        var currentPriority = 1
        var lastScore: CGFloat = -1

        for (index, item) in sorted.enumerated() {
            // If this score is different from the last, increment priority
            if index > 0 && item.heightScore < lastScore {
                currentPriority = index + 1
            }

            let heightInPixels = item.heightScore
            // Simple heuristic: assume 72 DPI standard
            let estimatedPointSize = heightInPixels * 0.75

            results.append(TextImportance(
                text: item.feature.text,
                confidence: item.feature.confidence,
                boundingBox: item.feature.boundingBox,
                priority: currentPriority,
                estimatedPointSize: estimatedPointSize,
                heightInPixels: heightInPixels
            ))

            lastScore = item.heightScore
        }

        return results
    }
}
