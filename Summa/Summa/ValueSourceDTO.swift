//
//  ValueSourceDTO.swift
//  Summa
//
//  Created by Till Gartner on 26.08.25.
//

import Foundation
import SwiftData

struct ValueSnapshotDTO: Identifiable, Codable, Hashable, Comparable {
    let id: UUID
    let date: Date
    let value: Double
    
    init(on:Date, value:Double) {
        self.id = UUID()
        self.date = on
        self.value = value
    }
    
    static func < (lhs: ValueSnapshotDTO, rhs: ValueSnapshotDTO) -> Bool {
        lhs.date < rhs.date
    }
}

@Observable
class ValueSourceDTO: Identifiable, Codable {
    private var isAdjustingValueHistory = false // Needed to avoid infinite recursion of didSet
    var valueHistory = [ValueSnapshotDTO]()
    
    
    init() {
        if let savedValues = UserDefaults.standard.data(forKey: "ValueSnapshots") {
            if let decodedValues = try? JSONDecoder().decode(
                [ValueSnapshotDTO].self,
                from: savedValues
            ) {
                valueHistory = decodedValues
                return
            }
        }
        valueHistory = []
        
    }
}


