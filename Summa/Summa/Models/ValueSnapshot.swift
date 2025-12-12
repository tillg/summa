//
//  ValueSnapshot.swift
//  Summa
//
//  Created by Till Gartner on 09.08.25.
//

import Foundation
import SwiftData

@Model
class ValueSnapshot: Identifiable, Equatable, Hashable, Comparable {
    var id: UUID = UUID()
    var date: Date? = Date.now  // Optional - nil indicates date unknown
    var value: Double? = nil  // Optional - nil indicates value not yet extracted/entered
    var series: Series?

    // Processing state flags
    var humanConfirmed: Bool = false  // Has user explicitly saved/edited this snapshot?
    var valueExtractionAttempted: Bool = false  // Have we tried extracting value from screenshot?

    // Screenshot data
    var sourceImage: Data?  // Original screenshot
    var imageAttachedDate: Date?  // When screenshot was added

    // Analysis metadata (for debugging/history)
    var extractedValue: Double?  // Value extracted by Vision analysis
    var extractedText: String?  // Raw text that was analyzed
    var analysisConfidence: Float?  // Confidence score (0.0 to 1.0)
    var analysisDate: Date?  // When analysis was performed
    var analysisError: String?  // Error message if analysis failed

    // Visual fingerprint data for series matching
    var fingerprintData: Data?  // VNFeaturePrintObservation data
    var fingerprintRevision: Int?  // Algorithm revision used (e.g., VNGenerateImageFeaturePrintRequestRevision2)

    init(on: Date?, value: Double?, series: Series? = nil, humanConfirmed: Bool = false) {
        self.id = UUID()
        self.date = on
        self.value = value
        self.series = series
        self.humanConfirmed = humanConfirmed
    }

    /// Creates a snapshot from a screenshot that needs analysis
    static func fromScreenshot(_ imageData: Data, date: Date? = nil) -> ValueSnapshot {
        let snapshot = ValueSnapshot(on: date, value: nil, series: nil, humanConfirmed: false)
        snapshot.sourceImage = imageData
        snapshot.imageAttachedDate = Date()
        return snapshot
    }

    static func < (lhs: ValueSnapshot, rhs: ValueSnapshot) -> Bool {
        // Handle nil dates by treating them as distant past (sort to beginning)
        let lhsDate = lhs.date ?? Date.distantPast
        let rhsDate = rhs.date ?? Date.distantPast
        return lhsDate < rhsDate
    }
    static func == (lhs: ValueSnapshot, rhs: ValueSnapshot) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
