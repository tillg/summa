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
    // App Group identifier for shared container with Share Extension
    private let appGroupIdentifier = "group.com.grtnr.Summa"

    @State private var syncMonitor = CloudKitSyncMonitor()
    @State private var showSyncError = false

    var sharedModelContainer: ModelContainer = {
        // Get App Group container URL
        guard let appGroupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.grtnr.Summa") else {
            print("❌ ERROR: Failed to get App Group container")
            fatalError("Failed to get App Group container")
        }

        let storeURL = appGroupURL.appending(path: "Summa.sqlite")
        print("📁 SwiftData store location: \(storeURL.path)")

        // Check if database file exists
        if FileManager.default.fileExists(atPath: storeURL.path) {
            print("✅ Database file exists at App Group location")
        } else {
            print("⚠️ Database file does NOT exist yet (will be created)")
        }

        let config = ModelConfiguration(url: storeURL)

        do {
            let container = try ModelContainer(
                for: ValueSnapshot.self, Series.self,
                configurations: config
            )
            print("✅ ModelContainer created successfully")
            return container
        } catch {
            print("❌ ERROR creating ModelContainer: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 800, minHeight: 600)
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
                            .cornerRadius(16)
                            .shadow(radius: 10)
                        }
                    }
                }
                .environment(syncMonitor)
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
        .defaultSize(width: 1200, height: 800)
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
