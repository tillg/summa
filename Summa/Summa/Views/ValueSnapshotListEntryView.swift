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
            // Disable editing while analyzing
            if snapshot.analysisState != .analyzing {
                onTap()
            }
        } label: {
            rowContent
        }
        .buttonStyle(.plain)
        .listRowBackground(backgroundColor)
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 8) {
            // Series color indicator (only for humanConfirmed with series)
            if let series = snapshot.series, snapshot.analysisState == .humanConfirmed {
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

            // Right edge indicators
            HStack(spacing: 4) {
                // Image attachment indicator with state encoding
                if snapshot.sourceImage != nil {
                    photoIcon
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Photo Icon with State Encoding

    @ViewBuilder
    private var photoIcon: some View {
        switch snapshot.analysisState {
        case .pendingAnalysis:
            // Blue = New, needs to be analyzed
            Image(systemName: "photo")
                .font(.caption2)
                .foregroundColor(.blue)
        case .analyzing:
            // Spinning animation = Analysis running
            HStack(spacing: 2) {
                Image(systemName: "photo")
                    .font(.caption2)
                    .foregroundColor(.blue)
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 8, height: 8)
            }
        case .analysisCompleteFull:
            // Green = Analysis successful
            Image(systemName: "photo")
                .font(.caption2)
                .foregroundColor(.green)
        case .analysisCompletePartial:
            // Orange = Partially successful
            Image(systemName: "photo")
                .font(.caption2)
                .foregroundColor(.orange)
        case .analysisFailed:
            // Red = Analysis failed
            Image(systemName: "photo")
                .font(.caption2)
                .foregroundColor(.red)
        case .humanConfirmed:
            // Gray = Human confirmed (neutral state)
            Image(systemName: "photo")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Background Color

    private var backgroundColor: Color? {
        switch snapshot.analysisState {
        case .pendingAnalysis, .analyzing, .analysisCompletePartial, .analysisFailed:
            return Color.gray.opacity(0.15)
        case .analysisCompleteFull:
            return Color.gray.opacity(0.08)  // Light gray
        case .humanConfirmed:
            return nil  // No background
        }
    }

    // MARK: - Regular Layout (iPad)

    private var regularLayoutContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(snapshot.date.formatted(date: .abbreviated, time: .shortened))
                    .lineLimit(1)

                #if DEBUG
                Text("[\(stateDebugName)]")
                    .font(.caption2)
                    .foregroundColor(.purple)
                #endif
            }

            HStack {
                if let series = snapshot.series {
                    Text(series.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                if let value = snapshot.value {
                    Text(value.formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR")))
                        .fontWeight(.medium)
                }
            }
        }
    }

    #if DEBUG
    private var stateDebugName: String {
        switch snapshot.analysisState {
        case .pendingAnalysis: return "PENDING"
        case .analyzing: return "ANALYZING"
        case .analysisCompletePartial: return "PARTIAL"
        case .analysisCompleteFull: return "FULL"
        case .analysisFailed: return "FAILED"
        case .humanConfirmed: return "HUMAN"
        }
    }
    #endif

    // MARK: - Compact Layout (iPhone)

    private var compactLayoutContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(snapshot.date.formatted(date: .abbreviated, time: .shortened))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                #if DEBUG
                Text("[\(stateDebugName)]")
                    .font(.caption2)
                    .foregroundColor(.purple)
                #endif
            }

            HStack {
                if let series = snapshot.series {
                    Text(series.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
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

#Preview("Completed Snapshot - iPhone") {
    let previewSeries = Series(name: "Comdirect", color: "#FFC107", sortOrder: 0)

    List {
        ValueSnapshotListEntryView(
            snapshot: ValueSnapshot(on: Date(), value: 1332.00, series: previewSeries, analysisState: .humanConfirmed, dataSource: .human),
            horizontalSizeClass: .compact,
            onTap: {}
        )
    }
    .listStyle(.plain)
}

#Preview("Completed Snapshot - iPad") {
    let previewSeries = Series(name: "HVB", color: "#F44336", sortOrder: 0)

    List {
        ValueSnapshotListEntryView(
            snapshot: ValueSnapshot(on: Date(), value: 16000.00, series: previewSeries, analysisState: .humanConfirmed, dataSource: .human),
            horizontalSizeClass: .regular,
            onTap: {}
        )
    }
    .listStyle(.plain)
}

#Preview("Mixed List - All States - iPhone") {
    let series1 = Series(name: "Comdirect", color: "#FFC107", sortOrder: 0)
    let series2 = Series(name: "HVB", color: "#F44336", sortOrder: 1)
    let series3 = Series(name: "Savings", color: "#4CAF50", sortOrder: 2)

    // Dummy screenshot data for preview
    let dummyImageData = Data([0xFF, 0xD8, 0xFF, 0xE0])  // JPEG header

    List {
        // 1. pendingAnalysis - Waiting to be analyzed
        ValueSnapshotListEntryView(
            snapshot: {
                let snap = ValueSnapshot(on: Date(), value: nil, series: nil, analysisState: .pendingAnalysis, dataSource: .robot)
                snap.sourceImage = dummyImageData
                return snap
            }(),
            horizontalSizeClass: .compact,
            onTap: {}
        )

        // 2. analyzing - Currently being processed
        ValueSnapshotListEntryView(
            snapshot: {
                let snap = ValueSnapshot(on: Date().addingTimeInterval(-60), value: nil, series: nil, analysisState: .analyzing, dataSource: .robot)
                snap.sourceImage = dummyImageData
                return snap
            }(),
            horizontalSizeClass: .compact,
            onTap: {}
        )

        // 3. analysisCompleteFull - Successfully extracted value AND series
        ValueSnapshotListEntryView(
            snapshot: {
                let snap = ValueSnapshot(on: Date().addingTimeInterval(-3600), value: 1250.50, series: series1, analysisState: .analysisCompleteFull, dataSource: .robot)
                snap.sourceImage = dummyImageData
                snap.extractedValue = 1250.50
                snap.analysisConfidence = 0.95
                return snap
            }(),
            horizontalSizeClass: .compact,
            onTap: {}
        )

        // 4. analysisCompletePartial - Extracted value but no series
        ValueSnapshotListEntryView(
            snapshot: {
                let snap = ValueSnapshot(on: Date().addingTimeInterval(-7200), value: 5432.10, series: nil, analysisState: .analysisCompletePartial, dataSource: .robot)
                snap.sourceImage = dummyImageData
                snap.extractedValue = 5432.10
                snap.analysisConfidence = 0.88
                return snap
            }(),
            horizontalSizeClass: .compact,
            onTap: {}
        )

        // 5. analysisFailed - Analysis failed with error
        ValueSnapshotListEntryView(
            snapshot: {
                let snap = ValueSnapshot(on: Date().addingTimeInterval(-10800), value: nil, series: nil, analysisState: .analysisFailed, dataSource: .robot)
                snap.sourceImage = dummyImageData
                snap.analysisError = "No monetary value detected"
                return snap
            }(),
            horizontalSizeClass: .compact,
            onTap: {}
        )

        // 6. humanConfirmed (human entered) - Manual entry without screenshot
        ValueSnapshotListEntryView(
            snapshot: ValueSnapshot(on: Date().addingTimeInterval(-86400), value: 1332.00, series: series2, analysisState: .humanConfirmed, dataSource: .human),
            horizontalSizeClass: .compact,
            onTap: {}
        )

        // 7. humanConfirmed (robot -> human) - User edited auto-extracted data, with screenshot
        ValueSnapshotListEntryView(
            snapshot: {
                let snap = ValueSnapshot(on: Date().addingTimeInterval(-172800), value: 16250.00, series: series3, analysisState: .humanConfirmed, dataSource: .human)
                snap.sourceImage = dummyImageData
                snap.extractedValue = 16000.00  // Original extracted value was different
                snap.analysisConfidence = 0.92
                return snap
            }(),
            horizontalSizeClass: .compact,
            onTap: {}
        )
    }
    .listStyle(.plain)
}
