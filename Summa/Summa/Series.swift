//
//  Series.swift
//  Summa
//
//  Created by Till Gartner on 11.11.25.
//

import Foundation
import SwiftData

@Model
class Series {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "" // Hex color
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade) var snapshots: [ValueSnapshot]?

    init(name: String, color: String, sortOrder: Int) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.snapshots = nil
    }
}
