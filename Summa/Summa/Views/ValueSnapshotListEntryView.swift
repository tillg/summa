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
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            rowContent
        }
        .buttonStyle(.plain)
        .listRowBackground(backgroundColor)
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 8) {
            // Series color indicator (left side)
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

            Spacer()

            // Image icon (right side) - simple, no color coding or spinner
            if snapshot.sourceImage != nil {
                Image(systemName: "photo")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Background Color

    private var backgroundColor: Color? {
        // Simple rule: grey if robot-created, no background if user-confirmed
        if !snapshot.humanConfirmed {
            return Color.gray.opacity(0.12)
        }
        return nil  // No background (white/system)
    }

    // MARK: - Regular Layout (iPad)

    private var regularLayoutContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.date?.formatted(date: .abbreviated, time: .shortened) ?? "Date unknown")
                .lineLimit(1)

            HStack {
                if let series = snapshot.series {
                    Text(series.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if let value = snapshot.value {
                    Text(value.formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR")))
                        .fontWeight(.medium)
                }
            }
        }
    }

    // MARK: - Compact Layout (iPhone)

    private var compactLayoutContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.date?.formatted(date: .abbreviated, time: .shortened) ?? "Date unknown")
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            HStack {
                if let series = snapshot.series {
                    Text(series.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let value = snapshot.value {
                    Text(value.formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR")))
                        .fontWeight(.medium)
                }
            }
        }
    }
}

#Preview("User-Confirmed Snapshot - iPhone") {
    let previewSeries = Series(name: "Comdirect", color: "#FFC107", sortOrder: 0)

    List {
        ValueSnapshotListEntryView(
            snapshot: ValueSnapshot(on: Date(), value: 1332.00, series: previewSeries, humanConfirmed: true),
            horizontalSizeClass: .compact,
            onTap: {}
        )
    }
    .listStyle(.plain)
}

#Preview("User-Confirmed Snapshot - iPad") {
    let previewSeries = Series(name: "HVB", color: "#F44336", sortOrder: 0)

    List {
        ValueSnapshotListEntryView(
            snapshot: ValueSnapshot(on: Date(), value: 16000.00, series: previewSeries, humanConfirmed: true),
            horizontalSizeClass: .regular,
            onTap: {}
        )
    }
    .listStyle(.plain)
}

#Preview("Mixed States - iPhone") {
    let series1 = Series(name: "Comdirect", color: "#FFC107", sortOrder: 0)
    let series2 = Series(name: "HVB", color: "#F44336", sortOrder: 1)

    // Dummy screenshot data for preview
    let dummyImageData = Data([0xFF, 0xD8, 0xFF, 0xE0])  // JPEG header

    List {
        // 1. Needs processing - No value yet, not attempted
        ValueSnapshotListEntryView(
            snapshot: {
                let snap = ValueSnapshot(on: Date(), value: nil, series: nil, humanConfirmed: false)
                snap.sourceImage = dummyImageData
                snap.valueExtractionAttempted = false
                return snap
            }(),
            horizontalSizeClass: .compact,
            onTap: {}
        )

        // 2. Auto-extracted, needs series
        ValueSnapshotListEntryView(
            snapshot: {
                let snap = ValueSnapshot(on: Date().addingTimeInterval(-3600), value: 1250.50, series: nil, humanConfirmed: false)
                snap.sourceImage = dummyImageData
                snap.valueExtractionAttempted = true
                return snap
            }(),
            horizontalSizeClass: .compact,
            onTap: {}
        )

        // 3. Auto-extracted with series (complete, grey background since not confirmed)
        ValueSnapshotListEntryView(
            snapshot: {
                let snap = ValueSnapshot(on: Date().addingTimeInterval(-7200), value: 1250.50, series: series1, humanConfirmed: false)
                snap.sourceImage = dummyImageData
                snap.valueExtractionAttempted = true
                snap.fingerprintData = dummyImageData  // Has fingerprint
                return snap
            }(),
            horizontalSizeClass: .compact,
            onTap: {}
        )

        // 4. Extraction failed - tried but no value found
        ValueSnapshotListEntryView(
            snapshot: {
                let snap = ValueSnapshot(on: Date().addingTimeInterval(-10800), value: nil, series: nil, humanConfirmed: false)
                snap.sourceImage = dummyImageData
                snap.valueExtractionAttempted = true
                snap.analysisError = "No monetary value detected"
                return snap
            }(),
            horizontalSizeClass: .compact,
            onTap: {}
        )

        // 5. User-confirmed - Manual entry without screenshot
        ValueSnapshotListEntryView(
            snapshot: ValueSnapshot(on: Date().addingTimeInterval(-86400), value: 1332.00, series: series2, humanConfirmed: true),
            horizontalSizeClass: .compact,
            onTap: {}
        )

        // 6. User-confirmed - User edited auto-extracted data
        ValueSnapshotListEntryView(
            snapshot: {
                let snap = ValueSnapshot(on: Date().addingTimeInterval(-172800), value: 16250.00, series: series2, humanConfirmed: true)
                snap.sourceImage = dummyImageData
                return snap
            }(),
            horizontalSizeClass: .compact,
            onTap: {}
        )
    }
    .listStyle(.plain)
}
