# Standardizing CloudKit Configuration Between Main App and Share Extension

Currently the main app and Share Extension have **duplicate ModelContainer creation code**, and critically, the Share Extension is **missing CloudKit configuration**. This causes data saved via the Share Extension to not sync to iCloud.

## Current Implementation

**Main App** (`SummaApp.swift:20-64`):

```swift
var sharedModelContainer: ModelContainer = {
    guard let appGroupURL = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier) else {
        fatalError("Failed to get App Group container")
    }

    let storeURL = appGroupURL.appending(path: AppConstants.databaseFileName)

    let config = ModelConfiguration(
        url: storeURL,
        cloudKitDatabase: .private("iCloud.com.grtnr.Summa")  // ✅ CloudKit enabled
    )

    return try! ModelContainer(
        for: ValueSnapshot.self, Series.self,
        configurations: config
    )
}()
```

**Share Extension** (`ShareViewController.swift:30-62`):

```swift
private func createModelContainer() throws -> ModelContainer {
    guard let appGroupURL = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier) else {
        throw NSError(...)
    }

    let storeURL = appGroupURL.appending(path: AppConstants.databaseFileName)

    let config = ModelConfiguration(url: storeURL)  // ❌ NO CloudKit!

    return try ModelContainer(
        for: ValueSnapshot.self, Series.self,
        configurations: config
    )
}
```

## Problem Statement

**Why this matters:**

### 1. CloudKit Sync Bug 🐛
- Share Extension writes data **without CloudKit configuration**
- Data saved via Share Extension writes to **local SQLite only** (no CloudKit metadata)
- Data only syncs **after main app opens and re-saves it** (during analysis)
- Creates window of vulnerability where data can be lost

**What actually happens (normal flow):**

1. Share Extension saves snapshot to local database (no CloudKit metadata)
2. User opens main app on same device
3. Main app loads snapshot from local database ✓
4. Main app analyzes and re-saves through CloudKit-enabled container
5. **Now** it syncs to iCloud ✓
6. Other devices receive the snapshot ✓

**The bug is masked by the main app**, but creates risk in these scenarios:

**Scenario A: Device lost before main app opens**
1. Share 5 screenshots via extension throughout the day
2. Never open main app
3. Device is lost/stolen/broken
4. All 5 snapshots lost forever ❌ (never synced to iCloud)

**Scenario B: Immediate device switch**
1. iPhone: Share screenshot via extension (local only)
2. iPhone: Don't open main app
3. iPad: Open main app immediately
4. Screenshot NOT visible on iPad ❌ (hasn't synced yet)
5. Hours later, iPhone: Open main app
6. Now it syncs to iPad ✓ (but delayed)

**Scenario C: Extension-only usage**
1. User primarily uses share extension
2. Rarely opens main app
3. Days/weeks of data sitting unsynced locally
4. High risk of data loss if device fails

### 2. Code Duplication
- ~35 lines of nearly identical code in two places
- High maintenance burden - must update both files for any config change
- Already caused the CloudKit bug above (missing parameter in one location)
- Violates DRY principle

### 3. Configuration Drift Risk
- No guarantee both implementations stay in sync
- Easy to update one and forget the other
- No single source of truth for database configuration

## Solution: Shared ModelContainer Factory

**Key insight:** Extract container creation logic to shared utility that both targets use.

**Architecture:** Create a factory class that encapsulates all ModelContainer setup:

```
Before:
┌─────────────┐    ┌──────────────────┐
│  Main App   │    │ Share Extension  │
├─────────────┤    ├──────────────────┤
│ Container   │    │ Container        │
│ Setup Code  │    │ Setup Code       │
│ (45 lines)  │    │ (32 lines)       │
│             │    │                  │
│ ✅ CloudKit  │    │ ❌ CloudKit      │
└─────────────┘    └──────────────────┘

After:
┌─────────────┐    ┌──────────────────┐
│  Main App   │    │ Share Extension  │
├─────────────┤    ├──────────────────┤
│ Calls       │    │ Calls            │
│ Factory     │    │ Factory          │
└──────┬──────┘    └────────┬─────────┘
       │                    │
       └──────┬─────────────┘
              ↓
    ┌──────────────────────┐
    │ ModelContainerFactory│
    ├──────────────────────┤
    │ ✅ CloudKit           │
    │ ✅ App Group          │
    │ ✅ Single Source      │
    └──────────────────────┘
```

## Implementation Plan

### Step 1: Create Shared Factory

**New file:** `Summa/Utils/ModelContainerFactory.swift`

```swift
import SwiftData
import Foundation

enum ModelContainerFactory {
    /// Creates the shared ModelContainer with CloudKit sync
    /// Used by both main app and share extension
    static func createSharedContainer() throws -> ModelContainer {
        guard let appGroupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier) else {
            throw NSError(
                domain: "ModelContainerFactory",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to access App Group container"]
            )
        }

        let storeURL = appGroupURL.appending(path: AppConstants.databaseFileName)

        #if DEBUG
        log("SwiftData store location: \(storeURL.path)")
        #endif

        let config = ModelConfiguration(
            url: storeURL,
            cloudKitDatabase: .private("iCloud.com.grtnr.Summa")
        )

        let container = try ModelContainer(
            for: ValueSnapshot.self, Series.self,
            configurations: config
        )

        #if DEBUG
        log("ModelContainer created successfully with CloudKit sync")
        #endif

        return container
    }
}
```

**Target membership:** Both `Summa` and `Summa Share Extension` targets

### Step 2: Update Main App

**File:** `SummaApp.swift:20-64`

**Before:**
```swift
var sharedModelContainer: ModelContainer = {
    // ~45 lines of setup code
}()
```

**After:**
```swift
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
```

**Net change:** Delete ~40 lines, replace with 8 lines calling factory

### Step 3: Update Share Extension

**File:** `ShareViewController.swift:30-62`

**Before:**
```swift
private func createModelContainer() throws -> ModelContainer {
    // ~32 lines of setup code (missing CloudKit)
}
```

**After:**
```swift
private func createModelContainer() throws -> ModelContainer {
    return try ModelContainerFactory.createSharedContainer()
}
```

**Net change:** Delete ~30 lines, replace with 1 line calling factory

### Step 4: Xcode Target Configuration

Ensure `ModelContainerFactory.swift` is added to both targets:
- ✅ Summa (main app)
- ✅ Summa Share Extension

## Files to Modify

1. **NEW:** `Summa/Utils/ModelContainerFactory.swift` (create new)
2. **UPDATE:** `Summa/SummaApp.swift` (lines 20-64)
3. **UPDATE:** `Summa Share Extension/ShareViewController.swift` (lines 30-62)

## Benefits

### Immediate Benefits
✅ **Fixes CloudKit bug** - Share Extension data will sync to iCloud
✅ **Eliminates duplication** - Single source of truth for database config
✅ **Reduces code** - Net deletion of ~60 lines
✅ **Prevents drift** - Impossible for configurations to diverge

### Long-term Benefits
✅ **Easier maintenance** - Change config in one place
✅ **Easier testing** - Can test factory independently
✅ **Reusable** - Other extensions can use same factory
✅ **Type-safe** - Compiler enforces consistency

## Testing Strategy

### Pre-Implementation (Document Bug)
1. Device A: Share screenshot via extension
2. Device B: Open app - screenshot should NOT appear (confirms bug)
3. Device A: OPen main app and wait for Image Analysis to kick in
4. Device B: Entry should appear (confirms CloudKit works for main app)

### Post-Implementation (Verify Fix)

#### Manual Integration Tests

**Test 1: Share Extension CloudKit Sync** (main test)
1. Device A: Share screenshot via extension
2. Device B: Verify screenshot appears ✅ (was failing before, if main app was not opened on Device A)

**Test 2: Main App No Regression**
1. Device A: Add entry via main app
2. Device B: Verify still syncs ✓

**Test 3: Bidirectional Sync**
1. Device A: Share screenshot (extension)
2. Device B: Add manual entry (main app)
3. Both devices: Verify both entries appear ✓

**Test 4: Database File Location**
1. Check console logs on both app and extension launch
2. Verify both log identical App Group store URL ✓

#### Debugging

**Console filters:**
```bash
# CloudKit activity
process:Summa subsystem:com.apple.cloudkit

# SwiftData logs
process:Summa category:SwiftData

# Factory logs
process:Summa "ModelContainer created"
```

**CloudKit Dashboard:**
1. Go to developer.apple.com/icloud/dashboard
2. Select `iCloud.com.grtnr.Summa`
3. Check Private Database → CD_ValueSnapshot records
4. Verify records created from both app and extension

### Success Criteria

✅ Fix is successful when:
1. Share Extension snapshots sync to other devices
2. Main app continues to work (no regression)
3. Console shows no CloudKit errors
4. Both targets log identical database path
5. CloudKit Dashboard shows records from both sources

## Risk Assessment

### Low Risk
- Database schema unchanged - no migration needed
- App Group configuration unchanged
- CloudKit container unchanged
- Only organizational refactoring + bug fix

### Potential Issues

**Build Error:** Factory not accessible to extension
- **Fix:** Ensure file added to both targets in Xcode

**Runtime Error:** "Failed to access App Group container"
- **Fix:** Verify App Group entitlements configured correctly

**CloudKit still doesn't sync:**
- Check CloudKit Console for schema errors
- Verify iCloud entitlements on both targets
- Confirm device signed into iCloud
- Check network connectivity

## Architecture Decision (by Till)

(To be filled in after review)

### Decision: Extract to Shared Factory

**Rationale:**
- Single source of truth for database configuration
- Fixes critical CloudKit sync bug
- Eliminates dangerous code duplication
- Minimal risk - organizational change only
- Easier to test and maintain

**Implementation:** Create `ModelContainerFactory.swift` in Utils folder, add to both targets, refactor both call sites to use factory.
