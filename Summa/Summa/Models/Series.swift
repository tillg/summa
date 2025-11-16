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
    var isDefault: Bool = false // Marks the default series
    @Relationship(deleteRule: .cascade) var snapshots: [ValueSnapshot]?

    init(name: String, color: String, sortOrder: Int, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.isDefault = isDefault
        self.snapshots = nil
    }
}
