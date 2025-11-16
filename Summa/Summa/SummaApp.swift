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
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 800, minHeight: 600)
                #endif
        }
        .modelContainer(for: [ValueSnapshot.self, Series.self])
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
