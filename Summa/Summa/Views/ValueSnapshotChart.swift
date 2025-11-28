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

    @State private var selectedPeriod: Date = Calendar.current.date(byAdding: .day, value: AppConstants.Chart.weekDays, to: Date.now) ?? Date.now

    private var valuesToDraw: [ValueSnapshot] {
        valueHistory.filter { snapshot in
            snapshot.date >= selectedPeriod &&
            snapshot.series != nil &&
            snapshot.value != nil &&  // Only show snapshots with values
            visibleSeriesIDs.contains(snapshot.series!.id)
        }
        .sorted { $0.date < $1.date }
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
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(spacing: horizontalSizeClass == .compact ? 10 : 12) {
            // Chart area
            Group {
                if valuesToDraw.isEmpty {
                    Text("No data for selected period")
                        .foregroundColor(.secondary)
                        .frame(minHeight: AppConstants.Chart.minHeight)
                        .frame(maxHeight: .infinity)
                } else {
                    Chart {
                        ForEach(allSeries.filter { series in
                            visibleSeriesIDs.contains(series.id) &&
                            !snapshotsForSeries(series).isEmpty
                        }) { series in
                            ForEach(snapshotsForSeries(series)) { snapshot in
                                if let value = snapshot.value {
                                    LineMark(
                                        x: .value("Date", snapshot.date),
                                        y: .value("Value", value),
                                        series: .value("Series", series.name)
                                    )
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
                            .foregroundColor(.secondary)
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
                                            .foregroundColor(visibleSeriesIDs.contains(series.id) ? .primary : .secondary)
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

#Preview {
    ValueSnapshotChart(
        valueHistory: [],
        allSeries: [],
        visibleSeriesIDs: .constant(Set<UUID>()),
        horizontalSizeClass: .regular
    )
    .modelContainer(for: [ValueSnapshot.self, Series.self])
    .padding()
}
