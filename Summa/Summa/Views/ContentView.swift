//
//  ContentView.swift
//  Summa
//
//  Created by Till Gartner on 09.08.25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(ScreenshotAnalysisService.self) var analysisService
    @Environment(CloudKitSyncMonitor.self) var syncMonitor
    @Query var valueHistory: [ValueSnapshot]
    @Query(sort: \Series.sortOrder) var allSeries: [Series]
    @State private var showingAddValueSnapshot: Bool = false
    @State private var showingSeriesManagement: Bool = false
    @State private var editingSnapshot: ValueSnapshot?
    @State private var visibleSeriesIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .compact {
                    compactLayout
                } else {
                    regularLayout
                }
            }
            .navigationTitle("Summa")
            .toolbar {
                #if os(macOS)
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingSeriesManagement = true
                    } label: {
                        Label("Series", systemImage: "line.3.horizontal")
                    }
                    .help("Manage series (⌘⇧S)")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddValueSnapshot = true
                    } label: {
                        Label("Add Entry", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    .help("Create new entry (⌘N)")
                }
                #else
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSeriesManagement = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add entry", systemImage: "plus") {
                        showingAddValueSnapshot = true
                    }
                }
                #endif
            }
        }
            #if os(macOS)
            .frame(minWidth: 500, minHeight: 400)
            #endif
            .sheet(isPresented: $showingAddValueSnapshot) {
                NavigationStack {
                    ValueSnapshotEditView(snapshot: nil)
                        .environment(\.modelContext, modelContext)
                }
                #if os(macOS)
                .presentationSizing(.form)
                #endif
            }
            .sheet(item: $editingSnapshot) { snapshot in
                NavigationStack {
                    ValueSnapshotEditView(snapshot: snapshot)
                        .environment(\.modelContext, modelContext)
                }
                #if os(macOS)
                .presentationSizing(.form)
                #endif
            }
            .sheet(isPresented: $showingSeriesManagement) {
                NavigationStack {
                    SeriesManagementView(allSeries: allSeries)
                }
                .environment(\.modelContext, modelContext)
                #if os(macOS)
                .presentationSizing(.form)
                #endif
            }
            .task {
                // Initialize all series as visible by default
                visibleSeriesIDs = Set(allSeries.map { $0.id })

                #if DEBUG
                // Debug: Log what data we have
                log("Total snapshots loaded: \(valueHistory.count)")
                let pendingAnalysisCount = valueHistory.filter { $0.analysisState == .pendingAnalysis }.count
                let analyzingCount = valueHistory.filter { $0.analysisState == .analyzing }.count
                let partialCount = valueHistory.filter { $0.analysisState == .analysisCompletePartial }.count
                let fullCount = valueHistory.filter { $0.analysisState == .analysisCompleteFull }.count
                let failedCount = valueHistory.filter { $0.analysisState == .analysisFailed }.count
                let completedCount = valueHistory.filter { $0.analysisState == .humanConfirmed }.count
                log("   - Pending Analysis: \(pendingAnalysisCount)")
                log("   - Analyzing: \(analyzingCount)")
                log("   - Complete Partial: \(partialCount)")
                log("   - Complete Full: \(fullCount)")
                log("   - Failed: \(failedCount)")
                log("   - Human Confirmed: \(completedCount)")

                if pendingAnalysisCount > 0 {
                    log("Snapshots pending analysis:")
                    for snapshot in valueHistory.filter({ $0.analysisState == .pendingAnalysis }) {
                        log("   - Date: \(snapshot.date), Has screenshot: \(snapshot.sourceImage != nil)")
                    }
                }
                #endif

                #if os(macOS)
                // Setup NotificationCenter observers for macOS menu commands
                setupMacOSMenuObservers()
                #endif
            }
            .onChange(of: allSeries) { _, newSeries in
                // Ensure newly added series are visible by default
                for series in newSeries {
                    if !visibleSeriesIDs.contains(series.id) {
                        visibleSeriesIDs.insert(series.id)
                    }
                }
            }
            .onChange(of: syncMonitor.lastImportDate) { _, _ in
                // Force UI refresh when CloudKit imports new data
                #if DEBUG
                log("CloudKit import detected, refreshing UI...")
                #endif
            }
    }

    #if os(macOS)
    /// Setup observers for macOS menu commands
    private func setupMacOSMenuObservers() {
        NotificationCenter.default.addObserver(
            forName: .showAddSnapshot,
            object: nil,
            queue: .main
        ) { _ in
            showingAddValueSnapshot = true
        }

        NotificationCenter.default.addObserver(
            forName: .showSeriesManagement,
            object: nil,
            queue: .main
        ) { _ in
            showingSeriesManagement = true
        }

        // Note: Time period selection would need to be passed to ValueSnapshotChart
        // This is a future enhancement - for now menu items will be there but not functional
    }
    #endif

    // MARK: - Layout Variations

    /// Compact layout for iPhone and iPad Split View (vertical stack)
    private var compactLayout: some View {
        VStack(spacing: 0) {
            chartSection
                .frame(height: 280)  // Fixed height that works for iPhone
            Divider()
            listSection
        }
    }

    /// Regular layout for iPad and Mac (horizontal two-column)
    private var regularLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                chartSection
                    .frame(minWidth: 400, maxWidth: .infinity)
                    .layoutPriority(1)

                Divider()

                listSection
                    .frame(minWidth: 280, maxWidth: .infinity)
            }
        }
    }

    // MARK: - Shared Components

    /// Chart section showing value trends
    private var chartSection: some View {
        ValueSnapshotChart(
            valueHistory: valueHistory,
            allSeries: allSeries,
            visibleSeriesIDs: $visibleSeriesIDs,
            horizontalSizeClass: horizontalSizeClass
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }

    /// List section showing value history
    private var listSection: some View {
        VStack(spacing: 0) {
            // Header bar similar to navigation bar
            HStack {
                Text("Value history")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            List {
                ForEach(valueHistory.sorted(by: >), id: \.self) { value in
                    ValueSnapshotListEntryView(
                        snapshot: value,
                        horizontalSizeClass: horizontalSizeClass,
                        onTap: { editingSnapshot = value }
                    )
                    #if os(iOS)
                    .hoverEffect(.lift)
                    #endif
                    .task(id: value.analysisState) {
                        // Automatically trigger analysis when state is pendingAnalysis
                        #if DEBUG
                        if value.analysisState == .pendingAnalysis {
                            log(".task triggered for snapshot in pendingAnalysis state")
                        }
                        #endif

                        if value.analysisState == .pendingAnalysis {
                            // Wait for UI to fully render and for user to see the row
                            // This ensures the analyzing state is visible
                            #if DEBUG
                            log("⏱️ Waiting 2 seconds before starting analysis to ensure UI is visible...")
                            #endif
                            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

                            #if DEBUG
                            log("Starting analysis now")
                            #endif
                            await analysisService.analyzeSnapshot(value, modelContext: modelContext)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

}

#Preview {
    ContentView()
}
