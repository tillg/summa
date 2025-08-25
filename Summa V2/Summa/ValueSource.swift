//
//  ValueSource.swift
//  Summa
//
//  Created by Till Gartner on 09.08.25.
//

import Foundation

enum AssetType: Codable {
    case account
    case stockPortfolio
    case cash
}

struct ValueSnapshot: Identifiable, Codable, Hashable, Comparable {
    let id: UUID
    let date: Date
    let value: Double
    
    init(on:Date, value:Double) {
        self.id = UUID()
        self.date = on
        self.value = value
    }
    
    static func < (lhs: ValueSnapshot, rhs: ValueSnapshot) -> Bool {
        lhs.date < rhs.date
    }
}

@Observable
class ValueSource: Identifiable, Codable {
    var valueHistory = [ValueSnapshot]() {
        didSet {
            if let encoded = try? JSONEncoder().encode(valueHistory) {
                UserDefaults.standard.set(encoded, forKey: "ValueSnapshots")
                print("Saved ValueSnapshots to UserDefaults")
            }
        }
    }
    
    init() {
        if let savedValues = UserDefaults.standard.data(forKey: "ValueSnapshots") {
            if let decodedValues = try? JSONDecoder().decode(
                [ValueSnapshot].self,
                from: savedValues
            ) {
                valueHistory = decodedValues
                return
            }
        }
        
        valueHistory = []
        
    }
    
    init(valueHistory: [ValueSnapshot]) {
        self.valueHistory = valueHistory
    }
    
    static let examples: ValueSource = ValueSource(valueHistory: [
        ValueSnapshot(on: Date(daysSinceNow: -30), value:16.7),
        ValueSnapshot(on: Date(daysSinceNow: -26), value:18.3),
        ValueSnapshot(on: Date(daysSinceNow:    -7), value:32.3),
        ValueSnapshot(on: Date(daysSinceNow: -20), value:17.1),
        ValueSnapshot(on: Date(daysSinceNow:    -17), value:20.3),
        ValueSnapshot(on: Date(daysSinceNow:    -12), value:26.3),
        ValueSnapshot(on: Date(daysSinceNow:    -5), value:22.3),
        ValueSnapshot(on: Date(daysSinceNow:    -3), value:35.3)
        ]
    )

}


