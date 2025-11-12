//
//  ValueSource.swift
//  Summa
//
//  Created by Till Gartner on 09.08.25.
//

import Foundation
import SwiftData

enum AssetType: Codable {
    case account
    case stockPortfolio
    case cash
}

@Model
class ValueSnapshot: Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date.now
    var value: Double = 0.0
    var notes: String? = nil
    var series: Series?

    init(id: UUID, value: Double) {
        self.id = id
        self.date = .now
        self.value = value
    }

    init(on: Date, value: Double, notes: String? = nil, series: Series? = nil) {
        self.id = UUID()
        self.date = on
        self.value = value
        self.notes = notes
        self.series = series
    }

    static func < (lhs: ValueSnapshot, rhs: ValueSnapshot) -> Bool {
        lhs.date < rhs.date
    }
    static func == (lhs: ValueSnapshot, rhs: ValueSnapshot) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
            hasher.combine(date)
            hasher.combine(value)
        }
}

//@Model
//class ValueSource: Identifiable {
//    var valueHistory = [ValueSnapshot]()
//        
//    init(valueHistory: [ValueSnapshot]) {
//        self.valueHistory = valueHistory
//    }
//    
//    static let examples: ValueSource = ValueSource(valueHistory: [
//        ValueSnapshot(on: Date(daysSinceNow: -30), value:16.7),
//        ValueSnapshot(on: Date(daysSinceNow: -26), value:18.3),
//        ValueSnapshot(on: Date(daysSinceNow:    -7), value:32.3),
//        ValueSnapshot(on: Date(daysSinceNow: -20), value:17.1),
//        ValueSnapshot(on: Date(daysSinceNow:    -17), value:20.3),
//        ValueSnapshot(on: Date(daysSinceNow:    -12), value:26.3),
//        ValueSnapshot(on: Date(daysSinceNow:    -5), value:22.3),
//        ValueSnapshot(on: Date(daysSinceNow:    -3), value:35.3)
//        ]
//    )
//
//}


