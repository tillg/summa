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
- `ValueSnapshot`: SwiftData `@Model` class storing value, date, and notes
- `ValueSourceDTO`: Observable class for DTOs (transitional, may be removed)
- Persistence: SwiftData model container configured in `SummaApp.swift`
- Data access: SwiftUI `@Query` property wrapper in views
- Model context: Environment-injected `modelContext` for CRUD operations
- Storage: CloudKit-backed SwiftData with automatic iCloud sync across devices

### Key Components

**ContentView**: Main view displaying chart and value history list
- Uses `@Query` to access SwiftData models directly
- Displays sorted list of value snapshots
- Provides add button to show modal sheet

**AddValueSnapshotView**: Modal form for adding new value snapshots
- Uses environment `modelContext` to insert new records
- TextField for value input with number formatting
- DatePicker for snapshot date
- Optional notes field

**ValueSnapshotChart**: Chart component with time period filtering (Week/Month/Year/All)
- Uses SwiftUI Charts framework
- Filters and sorts data based on selected period
- Dynamic Y-axis scaling based on visible data range
- Line chart visualization of value over time

### Code Organization

Swift files are located in `Summa/Summa/`:
- `SummaApp.swift` - App entry point with SwiftData container configuration
- `ContentView.swift` - Main UI with value history list
- `AddValueSnapshotView.swift` - Add entry form
- `ValueSnapshotChart.swift` - Chart visualization component
- `ValueSnapshot.swift` - SwiftData model
- `ValueSourceDTO.swift` - DTO classes (transitional)
- `DateExtension.swift` - Date utility extensions

## Working with SwiftData

- Models use `@Model` macro
- Access data via `@Query` in SwiftUI views
- Insert/delete via `modelContext.insert()` / `modelContext.delete()`
- Model container is configured in app entry point for `ValueSnapshot.self`
- Data syncs automatically to iCloud via CloudKit
- CloudKit capabilities are configured in the Xcode project
- Data is accessible across devices signed into the same iCloud account
