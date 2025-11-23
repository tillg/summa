//
//  ValueSnapshot.swift
//  Summa
//
//  Created by Till Gartner on 09.08.25.
//

import Foundation
import SwiftData

// Processing state for share sheet workflow
enum ProcessingState: String, Codable {
    case pending     // Image received via share sheet, needs user input
    case completed   // Fully populated snapshot (normal state)
}

@Model
class ValueSnapshot: Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date.now
    var value: Double? = 0.0  // Optional to support pending state
    var series: Series?
    var processingState: String = ProcessingState.completed.rawValue  // Store as String for SwiftData

    @Attribute(.externalStorage) var sourceImage: Data?  // Original screenshot stored externally
    var imageAttachedDate: Date?  // When image was added

    // Computed property for type-safe access to processingState
    var state: ProcessingState {
        get { ProcessingState(rawValue: processingState) ?? .completed }
        set { processingState = newValue.rawValue }
    }

    init(on: Date, value: Double?, series: Series? = nil, processingState: ProcessingState = .completed) {
        self.id = UUID()
        self.date = on
        self.value = value
        self.series = series
        self.processingState = processingState.rawValue
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
