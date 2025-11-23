//
//  ValueSnapshotListEntryPending.swift
//  Summa
//
//  Phase 2: Pending snapshot list entry with gray background
//

import SwiftUI
import SwiftData

struct ValueSnapshotListEntryPendingView: View {
    let snapshot: ValueSnapshot
    let horizontalSizeClass: UserInterfaceSizeClass?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Orange question mark indicator
            Image(systemName: "questionmark.circle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 12))
                .padding(.top, horizontalSizeClass == .regular ? 3 : 0)

            if horizontalSizeClass == .regular {
                // iPad layout
                regularLayout
            } else {
                // iPhone layout
                compactLayout
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - iPad Layout

    private var regularLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(snapshot.date.formatted(date: .abbreviated, time: .shortened))
                    .lineLimit(1)

                Image(systemName: "questionmark.circle")
                    .foregroundColor(.orange)
                    .font(.caption)
            }

            HStack {
                if let series = snapshot.series {
                    Text(series.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Text("Pending")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
            }
        }
    }

    // MARK: - iPhone Layout

    private var compactLayout: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(snapshot.date.formatted(date: .abbreviated, time: .shortened))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.orange)
                        .font(.caption)
                }

                if let series = snapshot.series {
                    Text(series.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text("Pending")
                .font(.caption)
                .foregroundColor(.orange)
                .fontWeight(.medium)
        }
    }
}

#Preview("Pending Snapshot - iPhone") {
    List {
        ValueSnapshotListEntryPendingView(
            snapshot: ValueSnapshot(on: Date(), value: nil, series: nil, processingState: .pending),
            horizontalSizeClass: .compact
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.gray.opacity(0.15))
    }
    .listStyle(.plain)
}

#Preview("Pending Snapshot - iPad") {
    let previewSeries = Series(name: "Savings", color: "#007AFF", sortOrder: 0)

    List {
        ValueSnapshotListEntryPendingView(
            snapshot: ValueSnapshot(on: Date(), value: nil, series: previewSeries, processingState: .pending),
            horizontalSizeClass: .regular
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.gray.opacity(0.15))
    }
    .listStyle(.plain)
}

#Preview("Multiple Pending - iPhone") {
    let series1 = Series(name: "Comdirect", color: "#FFC107", sortOrder: 0)
    let series2 = Series(name: "HVB", color: "#F44336", sortOrder: 1)

    List {
        // Pending without series
        ValueSnapshotListEntryPendingView(
            snapshot: ValueSnapshot(on: Date(), value: nil, series: nil, processingState: .pending),
            horizontalSizeClass: .compact
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.gray.opacity(0.15))

        // Pending with series assigned
        ValueSnapshotListEntryPendingView(
            snapshot: ValueSnapshot(on: Date().addingTimeInterval(-3600), value: nil, series: series1, processingState: .pending),
            horizontalSizeClass: .compact
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.gray.opacity(0.15))

        // Another pending with different series
        ValueSnapshotListEntryPendingView(
            snapshot: ValueSnapshot(on: Date().addingTimeInterval(-7200), value: nil, series: series2, processingState: .pending),
            horizontalSizeClass: .compact
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.gray.opacity(0.15))
    }
    .listStyle(.plain)
}
