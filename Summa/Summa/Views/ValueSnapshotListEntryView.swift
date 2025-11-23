//
//  SnapshotListEntryView.swift
//  Summa
//
//  Created for Phase 2: Share Sheet Integration
//

import SwiftUI
import SwiftData

struct ValueSnapshotListEntryView: View {
    let snapshot: ValueSnapshot
    let horizontalSizeClass: UserInterfaceSizeClass?

    var body: some View {
        // Use separate view for pending snapshots
        if snapshot.state == .pending {
            ValueSnapshotListEntryPendingView(snapshot: snapshot, horizontalSizeClass: horizontalSizeClass)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        } else {
            completedSnapshotView
        }
    }

    // MARK: - Completed Snapshot View

    private var completedSnapshotView: some View {
        HStack(alignment: .top, spacing: 8) {
            // Series color indicator
            if let series = snapshot.series {
                Circle()
                    .fill(SeriesManager.shared.colorFromHex(series.color))
                    .frame(width: AppConstants.UI.seriesIndicatorSize, height: AppConstants.UI.seriesIndicatorSize)
                    .padding(.top, horizontalSizeClass == .regular ? 3 : 0)
            }

            if horizontalSizeClass == .regular {
                // iPad layout: two lines
                regularLayoutContent
            } else {
                // iPhone layout: compact single line
                compactLayoutContent
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Regular Layout (iPad)

    private var regularLayoutContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(snapshot.date.formatted(date: .abbreviated, time: .shortened))
                    .lineLimit(1)

                if snapshot.state == .pending {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }

            HStack {
                if let series = snapshot.series {
                    Text(series.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                if snapshot.state == .pending {
                    Text("Pending")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                } else if let value = snapshot.value {
                    Text(value.formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR")))
                        .fontWeight(.medium)
                }
            }
        }
    }

    // MARK: - Compact Layout (iPhone)

    private var compactLayoutContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(snapshot.date.formatted(date: .abbreviated, time: .shortened))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    if snapshot.state == .pending {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }

                if let series = snapshot.series {
                    Text(series.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if snapshot.state == .pending {
                Text("Pending")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
            } else if let value = snapshot.value {
                Text(value.formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR")))
                    .fontWeight(.medium)
            }
        }
    }
}

#Preview("Completed Snapshot - iPhone") {
    let previewSeries = Series(name: "Comdirect", color: "#FFC107", sortOrder: 0)

    List {
        ValueSnapshotListEntryView(
            snapshot: ValueSnapshot(on: Date(), value: 1332.00, series: previewSeries, processingState: .completed),
            horizontalSizeClass: .compact
        )
    }
    .listStyle(.plain)
}

#Preview("Completed Snapshot - iPad") {
    let previewSeries = Series(name: "HVB", color: "#F44336", sortOrder: 0)

    List {
        ValueSnapshotListEntryView(
            snapshot: ValueSnapshot(on: Date(), value: 16000.00, series: previewSeries, processingState: .completed),
            horizontalSizeClass: .regular
        )
    }
    .listStyle(.plain)
}

#Preview("Mixed List - iPhone") {
    let series1 = Series(name: "Comdirect", color: "#FFC107", sortOrder: 0)
    let series2 = Series(name: "HVB", color: "#F44336", sortOrder: 1)

    List {
        // Pending snapshot
        ValueSnapshotListEntryView(
            snapshot: ValueSnapshot(on: Date(), value: nil, series: nil, processingState: .pending),
            horizontalSizeClass: .compact
        )

        // Completed snapshots
        ValueSnapshotListEntryView(
            snapshot: ValueSnapshot(on: Date().addingTimeInterval(-86400), value: 1332.00, series: series1, processingState: .completed),
            horizontalSizeClass: .compact
        )

        ValueSnapshotListEntryView(
            snapshot: ValueSnapshot(on: Date().addingTimeInterval(-172800), value: 16000.00, series: series2, processingState: .completed),
            horizontalSizeClass: .compact
        )
    }
    .listStyle(.plain)
}
