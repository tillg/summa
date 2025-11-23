//
//  CloudKitSyncMonitor.swift
//  Summa
//
//  Created for monitoring CloudKit sync state
//

import Foundation
import CoreData
import Observation

/// Monitors CloudKit sync state using NSPersistentCloudKitContainer notifications.
///
/// Uses modern Swift Observation framework (@Observable) for SwiftUI integration.
/// Tracks initial sync completion to prevent race conditions when initializing default data.
@Observable
class CloudKitSyncMonitor {

    enum SyncState {
        case notStarted
        case syncing
        case synced
    }

    var syncState: SyncState = .notStarted
    private var hasCompletedInitialSync: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedInitialSync") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedInitialSync") }
    }

    var lastError: Error?

    init() {
        // If we've already completed initial sync in a previous app launch, start as synced
        if hasCompletedInitialSync {
            syncState = .synced
        }

        // Subscribe to CloudKit container events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitEvent(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleCloudKitEvent(_ notification: Notification) {
        // Notifications arrive on background thread
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
            return
        }

        // Update state on main thread for SwiftUI observation
        Task { @MainActor in
            handleEvent(event)
        }
    }

    @MainActor
    private func handleEvent(_ event: NSPersistentCloudKitContainer.Event) {
        #if DEBUG
        let statusText = event.succeeded ? "succeeded" : "failed"
        #endif

        switch event.type {
        case .setup:
            #if DEBUG
            print("☁️ CloudKit: Setup event - \(statusText)")
            #endif
            if !event.succeeded {
                lastError = event.error
            }

        case .import:
            #if DEBUG
            print("☁️ CloudKit: Import event - \(statusText)")
            #endif
            if event.succeeded {
                // Initial import completed successfully
                if syncState != .synced {
                    #if DEBUG
                    print("✅ CloudKit: Initial sync completed")
                    #endif
                    syncState = .synced
                    hasCompletedInitialSync = true
                }
            } else {
                // Import failed
                #if DEBUG
                print("❌ CloudKit: Import failed - \(event.error?.localizedDescription ?? "unknown error")")
                #endif
                lastError = event.error
            }

        case .export:
            #if DEBUG
            print("☁️ CloudKit: Export event - \(statusText)")
            #endif
            if !event.succeeded {
                #if DEBUG
                print("⚠️ CloudKit: Export failed - \(event.error?.localizedDescription ?? "unknown error")")
                #endif
            }

        @unknown default:
            #if DEBUG
            print("☁️ CloudKit: Unknown event type")
            #endif
        }

        // If we're not synced yet and haven't seen any errors, we're syncing
        if syncState == .notStarted && lastError == nil {
            syncState = .syncing
        }
    }
}
