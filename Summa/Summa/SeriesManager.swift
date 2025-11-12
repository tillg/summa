//
//  SeriesManager.swift
//  Summa
//
//  Created by Till Gartner on 11.11.25.
//

import Foundation
import SwiftData
import SwiftUI

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
        var existingSeries = (try? modelContext.fetch(seriesDescriptor)) ?? []

        // Rename any "Net Worth" series to "Default" (legacy cleanup)
        var renamedCount = 0
        for series in existingSeries where series.name == "Net Worth" {
            series.name = "Default"
            renamedCount += 1
        }

        if renamedCount > 0 {
            try? modelContext.save()
            existingSeries = (try? modelContext.fetch(seriesDescriptor)) ?? []
        }

        // Clean up duplicate series with the same name (including after renaming)
        var seenNames: Set<String> = []
        var seriesToDelete: [Series] = []

        for series in existingSeries {
            if seenNames.contains(series.name) {
                seriesToDelete.append(series)
            } else {
                seenNames.insert(series.name)
            }
        }

        // Delete duplicates and reassign their snapshots to the kept series
        if !seriesToDelete.isEmpty {
            // Build a map of series names to the series we're keeping
            var keepSeries: [String: Series] = [:]
            for series in existingSeries where !seriesToDelete.contains(where: { $0.id == series.id }) {
                keepSeries[series.name] = series
            }

            // Reassign snapshots from duplicates to the kept series
            for duplicateSeries in seriesToDelete {
                if let keepingSeries = keepSeries[duplicateSeries.name],
                   let snapshots = duplicateSeries.snapshots {
                    for snapshot in snapshots {
                        snapshot.series = keepingSeries
                    }
                }
                modelContext.delete(duplicateSeries)
            }

            try? modelContext.save()
            // Refresh the series list after deletion
            existingSeries = (try? modelContext.fetch(seriesDescriptor)) ?? []
        }

        let defaultSeries: Series
        if existingSeries.isEmpty {
            // Create default series if none exist
            defaultSeries = Series(
                name: "Default",
                color: SeriesManager.predefinedColors[4], // Blue
                sortOrder: 0
            )
            modelContext.insert(defaultSeries)

            // Set as last used series
            UserDefaults.standard.set(defaultSeries.id.uuidString, forKey: "lastUsedSeriesID")
        } else {
            // Find the default series (first by sort order)
            defaultSeries = existingSeries.sorted(by: { $0.sortOrder < $1.sortOrder }).first!
        }

        // Assign all unassigned snapshots to the default series
        let snapshotDescriptor = FetchDescriptor<ValueSnapshot>()
        let allSnapshots = (try? modelContext.fetch(snapshotDescriptor)) ?? []
        let unassignedSnapshots = allSnapshots.filter { $0.series == nil }

        if !unassignedSnapshots.isEmpty {
            for snapshot in unassignedSnapshots {
                snapshot.series = defaultSeries
            }
        }

        try? modelContext.save()
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
