//
//  SummaApp.swift
//  Summa
//
//  Created by Till Gartner on 09.08.25.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

@main
struct SummaApp: App {
    @State private var syncMonitor = CloudKitSyncMonitor()
    @State private var analysisService = ScreenshotAnalysisService()
    @State private var analysisCoordinator = ImageAnalysisCoordinator()
    @State private var showSyncError = false

    var sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainerFactory.createSharedContainer()
        } catch {
            #if DEBUG
            logError("❌ ERROR creating ModelContainer: \(error)")
            #endif
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(minWidth: AppConstants.UI.minWindowWidth, minHeight: AppConstants.UI.minWindowHeight)
                #endif
                .overlay {
                    // Show loading overlay during initial sync
                    if syncMonitor.syncState == .syncing {
                        ZStack {
                            Color.black.opacity(0.4)
                                .ignoresSafeArea()

                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Syncing with iCloud...")
                                    .font(.headline)
                            }
                            .padding(32)
                            #if os(iOS)
                            .background(Color(uiColor: .systemBackground))
                            #elseif os(macOS)
                            .background(Color(nsColor: .windowBackgroundColor))
                            #endif
                            .clipShape(.rect(cornerRadius: 16))
                            .shadow(radius: 10)
                        }
                    }
                }
                .environment(syncMonitor)
                .environment(analysisService)
                .environment(analysisCoordinator)
                .onAppear {
                    // Set model context for SeriesManager
                    Task { @MainActor in
                        SeriesManager.shared.setModelContext(sharedModelContainer.mainContext)
                    }
                }
                .onChange(of: syncMonitor.syncState) { oldValue, newValue in
                    // When sync completes, initialize default series if needed
                    if newValue == .synced && oldValue != .synced {
                        Task { @MainActor in
                            SeriesManager.shared.initializeDefaultSeriesIfNeeded()
                        }
                    }

                    // Show error alert if sync failed
                    if syncMonitor.lastError != nil {
                        showSyncError = true
                    }
                }
                .alert("Sync Failed", isPresented: $showSyncError) {
                    Button("Quit", role: .destructive) {
                        #if os(iOS)
                        fatalError("CloudKit sync failed")
                        #elseif os(macOS)
                        NSApplication.shared.terminate(nil)
                        #endif
                    }
                } message: {
                    Text("Unable to sync with iCloud. Please check your network connection and iCloud settings.\n\nError: \(syncMonitor.lastError?.localizedDescription ?? "Unknown error")")
                }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: AppConstants.UI.defaultWindowWidth, height: AppConstants.UI.defaultWindowHeight)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Entry") {
                    NotificationCenter.default.post(name: .showAddSnapshot, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("View") {
                Button("Manage Series") {
                    NotificationCenter.default.post(name: .showSeriesManagement, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Menu("Time Period") {
                    Button("Week") {
                        NotificationCenter.default.post(name: .setTimePeriod, object: "week")
                    }
                    .keyboardShortcut("1", modifiers: .command)

                    Button("Month") {
                        NotificationCenter.default.post(name: .setTimePeriod, object: "month")
                    }
                    .keyboardShortcut("2", modifiers: .command)

                    Button("Year") {
                        NotificationCenter.default.post(name: .setTimePeriod, object: "year")
                    }
                    .keyboardShortcut("3", modifiers: .command)

                    Button("All Time") {
                        NotificationCenter.default.post(name: .setTimePeriod, object: "all")
                    }
                    .keyboardShortcut("4", modifiers: .command)
                }
            }
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

#if os(macOS)
// Notification names for menu commands
extension Notification.Name {
    static let showAddSnapshot = Notification.Name("showAddSnapshot")
    static let showSeriesManagement = Notification.Name("showSeriesManagement")
    static let setTimePeriod = Notification.Name("setTimePeriod")
}
#endif
