//
//  ValueSnapshot.swift
//  Summa
//
//  Created by Till Gartner on 09.08.25.
//

import Foundation
import SwiftData

@Model
class ValueSnapshot: Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date.now
    var value: Double = 0.0
    var series: Series?

    init(on: Date, value: Double, series: Series? = nil) {
        self.id = UUID()
        self.date = on
        self.value = value
        self.series = series
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
