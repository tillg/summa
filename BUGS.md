# BUGS

## ✅ FIXED: macOS CloudKit Sync Not Working

**Problem**: macOS app was not syncing data to/from CloudKit while iOS worked fine. CloudKit setup events failed silently.

**Root Causes:**
1. Missing `cloudKitDatabase` parameter in `ModelConfiguration` - was creating local-only storage
2. Missing `com.apple.security.network.client` entitlement for macOS App Sandbox

**Fix Applied (2025-12-02):**
- Added `cloudKitDatabase: .private("iCloud.com.grtnr.Summa")` to ModelConfiguration in SummaApp.swift
- Added network client entitlement to SummaDebug.entitlements for macOS sandbox
- Documented in CLAUDE.md and TESTING_GUIDE.md

---

## Full screen pictures don't show

When opening a valueSnapshot with an existing picture and tapping on the picture it should display the picture in full screen. It just shows an empty white sheet.

**Fix**: Remove the feature of opening the picture, as the thumbnails are big enough to see what's on them.

## ✅ FIXED: Default series added multiple times

When starting the App it takes some time before the Data from iCloud is read. In this time the App tests if there is a default series, and creates it if it doesn't exist. Then the real data comes in from iCloud - and we have 2 Default series...

**Fix: CloudKit sync state detection**

### Implementation Plan

**1. Create CloudKitSyncMonitor utility class** (`Utils/CloudKitSyncMonitor.swift`)

- [x] Create new `@Observable` class (modern Swift Observation, not `ObservableObject`)
- [x] Subscribe to `NSPersistentCloudKitContainer.eventChangedNotification` in initializer
- [x] Track sync state enum: `.notStarted`, `.syncing`, `.synced`
- [x] Expose observable properties for SwiftUI automatic tracking
- [x] Listen for `.import` event type with `.succeeded` property
- [x] Add `UserDefaults` flag "hasCompletedInitialSync" to remember sync completion across launches
- [x] Handle notification on background thread, update state on main thread

**2. Integrate sync monitor into app lifecycle** (`SummaApp.swift`)

- [x] Initialize `CloudKitSyncMonitor` in `SummaApp` with the model container
- [x] Use `@State` (not `@StateObject`) to hold sync monitor instance
- [x] Pass sync monitor via `.environment()` modifier (not `.environmentObject()`)
- [x] Start monitoring on app launch

**3. Update series initialization logic** (`Utils/SeriesManager.swift`)

- [x] Move Default series creation from current location to new `initializeDefaultSeriesIfNeeded()` method
- [x] Accept `ModelContext` as parameter to perform insertion
- [x] Only create Default series after CloudKit sync completes
- [x] Check both: no existing series AND sync is complete before creating Default
- [x] Call from SummaApp when sync monitor state changes to `.synced`

**4. Handle UI during sync**

- [x] Create loading overlay view that covers main UI during initial sync
- [x] Show centered `ProgressView` with "Syncing with iCloud..." message
- [x] Display on app launch when `syncState == .syncing`
- [x] Automatically dismiss when `syncState == .synced`
- [x] Use `.overlay()` modifier in SummaApp to layer over ContentView

**5. Handle sync failures and offline state**

- [x] Detect sync failure when event type is `.import` and `.succeeded == false`
- [x] Show alert dialog with error message when sync fails
- [x] Provide "Quit" button in alert to stop the app
- [x] Use `fatalError()` or exit gracefully after user acknowledges
- [x] Log error details for debugging

**6. Architecture considerations**

- CloudKit sync logic should NOT live in ContentView
- Create dedicated `CloudKitSyncMonitor` utility class in `Utils/` folder
- Use modern `@Observable` macro (iOS 17+), not `ObservableObject` protocol
- SeriesManager should remain responsible for series operations
- SummaApp coordinates between CloudKitSyncMonitor and SeriesManager
- Default series creation called from SummaApp after sync monitor state changes to `.synced`