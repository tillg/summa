//
//  ValueSnapshotChart.swift
//  Summa
//
//  Created by Till Gartner on 10.08.25.
//

import Foundation
import SwiftUI
import Charts


struct ValueSnapshotChart: View {

    let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date.now) ?? Date.now
    let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date.now) ?? Date.now
    let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date.now) ?? Date.now
    let everAgo = Calendar.current.date(byAdding: .year, value: -10, to: Date.now) ?? Date.now
    var valueHistory: [ValueSnapshot]
    var allSeries: [Series]
    @Binding var visibleSeriesIDs: Set<UUID>

    @State private var selectedPeriod: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date.now) ?? Date.now

    private var valuesToDraw: [ValueSnapshot] {
        valueHistory.filter { snapshot in
            snapshot.date >= selectedPeriod &&
            snapshot.series != nil &&
            visibleSeriesIDs.contains(snapshot.series!.id)
        }
        .sorted { $0.date < $1.date }
    }

    private var minValueToDraw: Double {
        valuesToDraw.min(by: { $0.value < $1.value })?.value ?? 0
    }

    private var maxValueToDraw: Double {
        valuesToDraw.max(by: { $0.value < $1.value })?.value ?? 0
    }

    // Group snapshots by series for drawing
    private func snapshotsForSeries(_ series: Series) -> [ValueSnapshot] {
        valuesToDraw
            .filter { $0.series?.id == series.id }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Chart area
            Group {
                if valuesToDraw.isEmpty {
                    Text("No data for selected period")
                        .foregroundColor(.secondary)
                        .frame(height: 200)
                } else {
                    Chart {
                        ForEach(allSeries.filter { series in
                            visibleSeriesIDs.contains(series.id) &&
                            !snapshotsForSeries(series).isEmpty
                        }) { series in
                            ForEach(snapshotsForSeries(series)) { snapshot in
                                LineMark(
                                    x: .value("Date", snapshot.date),
                                    y: .value("Value", snapshot.value),
                                    series: .value("Series", series.name)
                                )
                                .foregroundStyle(SeriesManager.shared.colorFromHex(series.color))
                                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            }
                        }
                    }
                    .chartYScale(domain: [minValueToDraw, maxValueToDraw])
                    .frame(height: 200)
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

            // Legend with visibility toggles
            if !allSeries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Series (tap to toggle)")
                        .font(.caption)
                        .foregroundColor(.secondary)

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
                                            .frame(width: 12, height: 12)
                                            .opacity(visibleSeriesIDs.contains(series.id) ? 1.0 : 0.3)

                                        Text(series.name)
                                            .font(.caption)
                                            .foregroundColor(visibleSeriesIDs.contains(series.id) ? .primary : .secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(uiColor: .systemGray6))
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
    // ValueSnapshotChart preview
}
