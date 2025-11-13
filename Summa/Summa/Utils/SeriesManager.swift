//
//  SeriesManager.swift
//  Summa
//
//  Created by Till Gartner on 11.11.25.
//

import Foundation
import SwiftData
import SwiftUI

/// Singleton service for managing Series lifecycle and utilities.
///
/// Responsibilities:
/// - Auto-creates "Default" series on first launch
/// - Manages last-used series persistence via UserDefaults
/// - Provides hex-to-Color conversion utility
/// - Maintains predefined color palette for series
class SeriesManager {
    static let shared = SeriesManager()

    // Predefined iOS system colors
    static let predefinedColors = [
        "#FF3B30", // Red
        "#FF9500", // Orange
        "#FFCC00", // Yellow
        "#34C759", // Green
        "#007AFF", // Blue
        "#5856D6", // Purple
        "#AF52DE", // Pink
        "#00C7BE", // Teal
        "#A2845E", // Brown
        "#8E8E93"  // Gray
    ]

    private var modelContext: ModelContext?

    @MainActor
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    @MainActor
    func initializeDefaultSeriesIfNeeded() {
        guard let modelContext = modelContext else { return }

        let seriesDescriptor = FetchDescriptor<Series>()
        let existingSeries = (try? modelContext.fetch(seriesDescriptor)) ?? []

        // Create default series if none exist
        if existingSeries.isEmpty {
            let defaultSeries = Series(
                name: "Default",
                color: SeriesManager.predefinedColors[4], // Blue
                sortOrder: 0
            )
            modelContext.insert(defaultSeries)

            // Set as last used series
            UserDefaults.standard.set(defaultSeries.id.uuidString, forKey: "lastUsedSeriesID")

            try? modelContext.save()
        }
    }

    func getLastUsedSeries(from allSeries: [Series]) -> Series? {
        guard let lastUsedIDString = UserDefaults.standard.string(forKey: "lastUsedSeriesID"),
              let lastUsedID = UUID(uuidString: lastUsedIDString) else {
            return allSeries.first
        }

        return allSeries.first { $0.id == lastUsedID } ?? allSeries.first
    }

    func setLastUsedSeries(_ series: Series) {
        UserDefaults.standard.set(series.id.uuidString, forKey: "lastUsedSeriesID")
    }

    func colorFromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        r = (int >> 16) & 0xFF
        g = (int >> 8) & 0xFF
        b = int & 0xFF

        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
