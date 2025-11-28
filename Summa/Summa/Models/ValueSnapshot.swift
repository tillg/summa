//
//  ValueSnapshot.swift
//  Summa
//
//  Created by Till Gartner on 09.08.25.
//

import Foundation
import SwiftData

/// Analysis state tracking for screenshot processing
enum AnalysisState: String, Codable {
    case pendingAnalysis      // Initial state, triggers analysis
    case analyzing            // Currently processing
    case analysisCompleteFull // All data extracted (value + series)
    case analysisCompletePartial // Partial data extracted (value only)
    case analysisFailed       // Analysis failed
    case humanConfirmed       // User validated/edited (terminal state)
}

/// Source of the snapshot data
enum DataSource: String, Codable {
    case robot  // Automatically extracted from screenshot
    case human  // Entered, edited, or implicitly confirmed by user
}

@Model
class ValueSnapshot: Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date.now
    var value: Double? = 0.0  // Optional to support pending state
    var series: Series?

    // Analysis state tracking
    var analysisStateRaw: String = AnalysisState.humanConfirmed.rawValue  // Store as String for SwiftData
    var dataSourceRaw: String = DataSource.human.rawValue  // Store as String for SwiftData

    // Screenshot data
    @Attribute(.externalStorage) var sourceImage: Data?  // Original screenshot stored externally
    var imageAttachedDate: Date?  // When screenshot was added

    // Analysis metadata
    var extractedValue: Double?  // Value extracted by Vision analysis
    var extractedText: String?  // Raw text that was analyzed
    var analysisConfidence: Float?  // Confidence score (0.0 to 1.0)
    var analysisDate: Date?  // When analysis was performed
    var analysisError: String?  // Error message if analysis failed

    // Computed properties for type-safe access
    var analysisState: AnalysisState {
        get { AnalysisState(rawValue: analysisStateRaw) ?? .humanConfirmed }
        set { analysisStateRaw = newValue.rawValue }
    }

    var dataSource: DataSource {
        get { DataSource(rawValue: dataSourceRaw) ?? .human }
        set { dataSourceRaw = newValue.rawValue }
    }

    init(on: Date, value: Double?, series: Series? = nil, analysisState: AnalysisState = .humanConfirmed, dataSource: DataSource = .human) {
        self.id = UUID()
        self.date = on
        self.value = value
        self.series = series
        self.analysisStateRaw = analysisState.rawValue
        self.dataSourceRaw = dataSource.rawValue
    }

    /// Creates a snapshot from a screenshot that needs analysis
    static func fromScreenshot(_ imageData: Data, date: Date = Date()) -> ValueSnapshot {
        let snapshot = ValueSnapshot(on: date, value: nil, series: nil, analysisState: .pendingAnalysis, dataSource: .robot)
        snapshot.sourceImage = imageData
        snapshot.imageAttachedDate = Date()
        return snapshot
    }

    static func < (lhs: ValueSnapshot, rhs: ValueSnapshot) -> Bool {
        lhs.date < rhs.date
    }
    static func == (lhs: ValueSnapshot, rhs: ValueSnapshot) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
