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
    var lastImportDate: Date?  // Tracks when last import completed

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
            log("DEBUG Setup event - \(statusText)")
            if !event.succeeded {
                if let error = event.error {
                    logError("DEBUG Setup failed with error: \(error)")
                    logError("DEBUG Setup error details: \(error.localizedDescription)")
                } else {
                    logError("DEBUG Setup failed with no error details")
                }
            }
            #endif
            if !event.succeeded {
                lastError = event.error
            }

        case .import:
            #if DEBUG
            log("DEBUG Import event - \(statusText)")
            #endif
            if event.succeeded {
                // Update last import timestamp to trigger view refreshes
                lastImportDate = Date()

                // Initial import completed successfully
                if syncState != .synced {
                    #if DEBUG
                    log("DEBUG Initial sync completed")
                    #endif
                    syncState = .synced
                    hasCompletedInitialSync = true
                }
            } else {
                // Import failed
                #if DEBUG
                logError("DEBUG Import failed - \(event.error?.localizedDescription ?? "unknown error")")
                #endif
                lastError = event.error
            }

        case .export:
            #if DEBUG
            log("DEBUG Export event - \(statusText)")
            if !event.succeeded {
                if let error = event.error {
                    logError("DEBUG Export failed with error: \(error)")
                    logError("DEBUG Export error details: \(error.localizedDescription)")
                    if let nsError = error as NSError? {
                        logError("DEBUG Export error domain: \(nsError.domain)")
                        logError("DEBUG Export error code: \(nsError.code)")
                        logError("DEBUG Export error userInfo: \(nsError.userInfo)")
                    }
                } else {
                    logError("DEBUG Export failed with no error details")
                }
            } else {
                log("DEBUG Export succeeded")
            }
            #endif

        @unknown default:
            #if DEBUG
            log("DEBUG Unknown event type")
            #endif
        }

        // If we're not synced yet and haven't seen any errors, we're syncing
        if syncState == .notStarted && lastError == nil {
            syncState = .syncing
        }
    }
}
