# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Summa is a personal wealth tracking iOS app for manually tracking net worth across multiple accounts (bank accounts, stock portfolios, etc.) without API integration.

Built for iOS using SwiftUI and SwiftData.

## Building and Running

This is an Xcode project for iOS development. Build and run using:

```bash
# Open the project in Xcode
open "Summa/Summa.xcodeproj"
```

Build within Xcode (Cmd+B) and run on simulator or device (Cmd+R).

## Architecture

### Data Model

**SwiftData-based persistence with CloudKit sync:**

**Series**: SwiftData `@Model` class for organizing value snapshots
- Stores name, color (hex string), sortOrder, and creation date
- Has optional relationship to snapshots with cascade delete
- Maximum 10 series allowed per app
- All fields have default values for CloudKit compatibility
- Predefined color palette of 10 iOS system colors

**ValueSnapshot**: SwiftData `@Model` class storing value, date, notes, and series
- Stores monetary value, timestamp, and optional notes
- Optional relationship to a Series

**Model Configuration:**
- Persistence: SwiftData model container configured in `SummaApp.swift` for both `ValueSnapshot` and `Series`
- Data access: SwiftUI `@Query` property wrapper in views
- Model context: Environment-injected `modelContext` for CRUD operations
- Storage: CloudKit-backed SwiftData with automatic iCloud sync across devices
- CloudKit requirement: All relationships must be optional

### Key Components

**ContentView**: Main view displaying chart and value history list
- Uses `@Query` to access SwiftData models for both snapshots and series
- Displays sorted list of value snapshots with series color indicators
- Provides add button and series management navigation
- Manages series visibility state for chart filtering

**AddValueSnapshotView**: Modal form for adding new value snapshots
- Series picker at top (remembers last used series via UserDefaults)
- TextField for value input with number formatting
- DatePicker for snapshot date
- Optional notes field (multi-line)
- Validates that a series is selected before saving

**ValueSnapshotChart**: Multi-series chart component with time period filtering
- Uses SwiftUI Charts framework with separate lines per series
- Time period options: Week/Month/Year/All
- Interactive legend with visibility toggles (tap series chips to show/hide)
- Each series rendered in its configured color
- Dynamic Y-axis scaling based on visible data range
- Horizontal scrolling legend for multiple series
- Empty state when no data available for selected period

**SeriesManagementView**: Full CRUD interface for managing series
- List view showing all series with latest values and entry counts
- Add/Edit series with name and color picker (10 predefined colors)
- Delete with name confirmation (user must type series name to confirm)
- Swipe-to-delete gesture
- Maximum 10 series enforcement
- Shows statistics per series

**SeriesManager**: Singleton service for series operations
- Auto-creates "Default" series on first launch
- Manages last used series persistence (UserDefaults)
- Provides hex-to-Color conversion utility
- Maintains predefined color palette

### Code Organization

Swift files are organized in `Summa/Summa/` with the following structure:

**Root:**
- `SummaApp.swift` - App entry point with SwiftData container configuration

**Models/** - SwiftData models
- `Series.swift` - Series SwiftData model
- `ValueSnapshot.swift` - ValueSnapshot SwiftData model with series relationship

**Views/** - SwiftUI views
- `ContentView.swift` - Main UI with chart and value history list
- `AddValueSnapshotView.swift` - Add entry form with series picker
- `ValueSnapshotChart.swift` - Multi-series chart visualization component
- `SeriesManagementView.swift` - Series CRUD interface (list and edit views)

**Utils/** - Utilities and services
- `SeriesManager.swift` - Series management service and utilities
- `CloudKitSyncMonitor.swift` - CloudKit sync state monitoring

## Working with SwiftData

- Models use `@Model` macro
- Access data via `@Query` in SwiftUI views
- Insert/delete via `modelContext.insert()` / `modelContext.delete()`
- Model container is configured in app entry point for both `ValueSnapshot.self` and `Series.self`
- Relationships use `@Relationship` macro (e.g., `@Relationship(deleteRule: .cascade)`)
- **CloudKit requirement**: All relationships must be optional (use `Type?` not `Type`)
- All model fields should have default values for CloudKit compatibility
- Data syncs automatically to iCloud via CloudKit
- CloudKit capabilities are configured in the Xcode project
- Data is accessible across devices signed into the same iCloud account

### CloudKit Configuration

**Critical Setup (SummaApp.swift):**
```swift
let config = ModelConfiguration(
    url: storeURL,
    cloudKitDatabase: .private("iCloud.com.grtnr.Summa")
)
```

**Platform-Specific Requirements:**
- **iOS**: Works automatically with iCloud entitlements
- **macOS**: Requires `com.apple.security.network.client` entitlement in `SummaDebug.entitlements` for App Sandbox network access
- **Both platforms**: Must have Background Modes capability with Remote notifications enabled (configured in Info.plist)

**Storage Considerations:**
- Images stored directly in database (not `.externalStorage`)
- CloudKit cannot automatically migrate between external and inline storage
- If schema changes require migration, delete CloudKit data via CloudKit Console and local databases

**Sync Behavior:**
- Exports triggered by: app backgrounding, system timing (batched)
- Imports triggered by: app launch, remote notifications
- Setup/Import/Export events logged via `CloudKitSyncMonitor`
- Failed events with retry are normal during startup

## Multiple Series Feature

The app supports tracking multiple series (e.g., different accounts, portfolios, asset types):

**Key Behaviors:**
- Maximum 10 series per app (enforced in UI)
- "Default" series auto-created on first launch
- Last used series remembered via UserDefaults (key: "lastUsedSeriesID")
- Series deletion requires name confirmation to prevent accidental data loss
- Cascade delete: deleting a series deletes all its snapshots
- Chart supports toggling series visibility via interactive legend
- Each series has a unique color from predefined palette
