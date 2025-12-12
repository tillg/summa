//
//  ValueSnapshotChart.swift
//  Summa
//
//  Created by Till Gartner on 10.08.25.
//

import Foundation
import SwiftUI
import SwiftData
import Charts


struct ValueSnapshotChart: View {

    let oneWeekAgo = Calendar.current.date(byAdding: .day, value: AppConstants.Chart.weekDays, to: Date.now) ?? Date.now
    let oneMonthAgo = Calendar.current.date(byAdding: .month, value: AppConstants.Chart.monthDuration, to: Date.now) ?? Date.now
    let oneYearAgo = Calendar.current.date(byAdding: .year, value: AppConstants.Chart.yearDuration, to: Date.now) ?? Date.now
    let everAgo = Calendar.current.date(byAdding: .year, value: AppConstants.Chart.allTimeDuration, to: Date.now) ?? Date.now
    var valueHistory: [ValueSnapshot]
    var allSeries: [Series]
    @Binding var visibleSeriesIDs: Set<UUID>
    var horizontalSizeClass: UserInterfaceSizeClass?

    @State private var selectedPeriod: Date = Calendar.current.date(byAdding: .year, value: AppConstants.Chart.allTimeDuration, to: Date.now) ?? Date.now

    private var valuesToDraw: [ValueSnapshot] {
        valueHistory.filter { snapshot in
            guard let date = snapshot.date,
                  let series = snapshot.series,
                  snapshot.value != nil else { return false }
            return date >= selectedPeriod &&
            visibleSeriesIDs.contains(series.id)
        }
        .sorted()
    }

    private var minValueToDraw: Double {
        valuesToDraw.compactMap { $0.value }.min() ?? 0
    }

    private var maxValueToDraw: Double {
        valuesToDraw.compactMap { $0.value }.max() ?? 0
    }

    // Group snapshots by series for drawing
    private func snapshotsForSeries(_ series: Series) -> [ValueSnapshot] {
        valuesToDraw
            .filter { $0.series?.id == series.id }
            .sorted()
    }

    var body: some View {
        VStack(spacing: horizontalSizeClass == .compact ? 10 : 12) {
            // Chart area
            Group {
                if valuesToDraw.isEmpty {
                    Text("No data for selected period")
                        .foregroundStyle(.secondary)
                        .frame(minHeight: AppConstants.Chart.minHeight)
                        .frame(maxHeight: .infinity)
                } else {
                    Chart {
                        ForEach(allSeries.filter { series in
                            visibleSeriesIDs.contains(series.id) &&
                            !snapshotsForSeries(series).isEmpty
                        }) { series in
                            ForEach(snapshotsForSeries(series)) { snapshot in
                                if let value = snapshot.value, let date = snapshot.date {
                                    LineMark(
                                        x: .value("Date", date),
                                        y: .value("Value", value),
                                        series: .value("Series", series.name)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(SeriesManager.shared.colorFromHex(series.color))
                                    .lineStyle(.init(lineWidth: AppConstants.Chart.lineWidth, lineCap: .round, lineJoin: .round))
                                }
                            }
                        }
                    }
                    .chartYScale(domain: [minValueToDraw, maxValueToDraw])
                    .frame(minHeight: AppConstants.Chart.minHeight)
                    .frame(maxHeight: .infinity)
                }
            }

            // Time period picker
            Picker("", selection: $selectedPeriod) {
                Text("Week").tag(oneWeekAgo)
                Text("Month").tag(oneMonthAgo)
                Text("Year").tag(oneYearAgo)
                Text("All").tag(everAgo)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 8)  // Add spacing after picker

            // Legend with visibility toggles
            if !allSeries.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    if horizontalSizeClass != .compact {
                        Text("Series (tap to toggle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Use native SwiftUI layout instead of custom FlowLayout
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allSeries) { series in
                                Button {
                                    if visibleSeriesIDs.contains(series.id) {
                                        visibleSeriesIDs.remove(series.id)
                                    } else {
                                        visibleSeriesIDs.insert(series.id)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(SeriesManager.shared.colorFromHex(series.color))
                                            .frame(width: AppConstants.UI.seriesIndicatorSize, height: AppConstants.UI.seriesIndicatorSize)
                                            .opacity(visibleSeriesIDs.contains(series.id) ? 1.0 : 0.3)

                                        Text(series.name)
                                            .font(.caption)
                                            .foregroundStyle(visibleSeriesIDs.contains(series.id) ? .primary : .secondary)
                                    }
                                    .padding(.horizontal, horizontalSizeClass == .compact ? 8 : 10)
                                    .padding(.vertical, horizontalSizeClass == .compact ? 4 : 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            #if os(iOS)
                                            .fill(Color(uiColor: .systemGray6))
                                            #else
                                            .fill(Color(nsColor: .systemGray).opacity(0.2))
                                            #endif
                                            .opacity(visibleSeriesIDs.contains(series.id) ? 1.0 : 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            }
        }
    }
}

#Preview("Chart with Data") {
    // Create 3 series with different colors
    let series1 = Series(name: "Savings Account", color: "#4CAF50", sortOrder: 0)
    let series2 = Series(name: "Stock Portfolio", color: "#2196F3", sortOrder: 1)
    let series3 = Series(name: "Crypto Wallet", color: "#FF9800", sortOrder: 2)

    let allSeries = [series1, series2, series3]

    // Generate realistic data for the last year
    var snapshots: [ValueSnapshot] = []
    let calendar = Calendar.current
    let now = Date()

    // Generate weekly data points for the last year
    for weekOffset in stride(from: -52, through: 0, by: 1) {
        guard let date = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: now) else { continue }

        // Series 1: Savings - steady growth from $10,000 to $12,000
        let savings = 10000 + Double(weekOffset + 52) * 40 + Double.random(in: -200...200)
        let snap1 = ValueSnapshot(on: date, value: savings, series: series1, humanConfirmed: true)
        snapshots.append(snap1)

        // Series 2: Stocks - more volatile, general upward trend from $25,000 to $32,000
        let stocks = 25000 + Double(weekOffset + 52) * 135 + Double.random(in: -1500...1500)
        let snap2 = ValueSnapshot(on: date, value: stocks, series: series2, humanConfirmed: true)
        snapshots.append(snap2)

        // Series 3: Crypto - very volatile, but trending up from $5,000 to $8,000
        let crypto = 5000 + Double(weekOffset + 52) * 58 + Double.random(in: -800...800)
        let snap3 = ValueSnapshot(on: date, value: crypto, series: series3, humanConfirmed: true)
        snapshots.append(snap3)
    }

    return ValueSnapshotChart(
        valueHistory: snapshots,
        allSeries: allSeries,
        visibleSeriesIDs: .constant(Set(allSeries.map { $0.id })),
        horizontalSizeClass: .regular
    )
    .modelContainer(for: [ValueSnapshot.self, Series.self])
    .padding()
    .frame(height: 400)
}

#Preview("Empty Chart") {
    ValueSnapshotChart(
        valueHistory: [],
        allSeries: [],
        visibleSeriesIDs: .constant(Set<UUID>()),
        horizontalSizeClass: .regular
    )
    .modelContainer(for: [ValueSnapshot.self, Series.self])
    .padding()
}
