# Identify series of screenshot

We can create new Snapshots by sharing screenshots to Summa. When the screenshots are added to Summa, some data is extracted automatically, namely the date of the screenshot and the value represented on the screenshot.

One data point that is not yet extracted is to which series the screen shot belongs.

How would a human identify to which series the screen shot belongs?:

* Take some example screen shots of every series
* Compare the newly added screen shot and try to find similarities to the screenshots of a series, like
* Color
* Fonts and font size
* If there are 2 series with very similar design (for example if a user has 2 series that represent the values of 2 bank accounts he has at the same bank), one would also use the size / magnitude of the value to assign it to either of the 2 visually similar series.

How could we implement such a functionality? What Apple Framework would we use? How would the process look like? What are the architectural options and decisions that need to be taken?

---

## Claude's Analysis and Suggestions

### Implementation Approach: Visual Fingerprinting

We'll use Apple's **Vision framework** to generate perceptual fingerprints of screenshots and compare them for similarity matching.

**Key APIs:**

* `VNGenerateImageFeaturePrintRequest` - Generates feature prints from images (available iOS 13+)
* `VNFeaturePrintObservation` - Contains the generated feature print
* `computeDistance(_:to:)` - Computes distance between two feature prints (shorter distance = higher similarity)
* `VNImageRequestHandler` - Processes screenshots for feature extraction

**How it works:**

1. When user first shares a screenshot to a series, store a visual fingerprint using `VNGenerateImageFeaturePrintRequest`
2. For each series, maintain 3-5 reference fingerprints from different screenshots
3. When new screenshot arrives, generate its fingerprint and compare against all stored series fingerprints
4. Use `computeDistance(_:to:)` to calculate similarity (distance) between fingerprints
5. If confidence is below threshold, ask user to manually select series

**Advantages:**

* Built-in iOS API (no custom ML training needed)
* Fast comparison
* Works out-of-box without training data
* Handles variations in the same UI (different values, dates, etc.)
* Privacy-preserving (perceptual hash, not actual images)

**Limitations:**

* Requires initial manual classification to build reference set
* May struggle with very similar UIs (same bank, different accounts)
* Fingerprints from different algorithm revisions cannot be compared

**Storage considerations:**

* Feature prints are ~1KB each
* Store directly in `ValueSnapshot.fingerprintData` as SwiftData blob
* Also store `fingerprintRevision: Int` to track algorithm version
* Syncs automatically via CloudKit with snapshot data

### Architecture

#### Data Model Extensions

```swift
@Model
class ValueSnapshot {
    // ... existing properties (value, date, notes, series)
    var screenshotImage: Data?  // Existing field
    var fingerprintData: Data?  // NEW: VNFeaturePrintObservation data
    var fingerprintRevision: Int?  // NEW: Track which algorithm revision was used
}

// No changes needed to Series model
```

**Thoughts about device/version compatibility:**

**Devices:** ✅ Cross-device compatible (iPhone, iPad, Mac, etc.) as long as same revision used

**iOS versions:** ⚠️ Must use same algorithm revision for comparison
* Revision 1: Available iOS 13.0+, macOS 10.15+ (all platforms)
* Revision 2: Available iOS 17.0+, macOS 14.0+ (newer, likely more accurate)
* Fingerprints from different revisions **cannot be compared**
* Solution: Explicitly set revision when creating request to ensure consistency
* **Recommendation:** Use Revision 2 (requires iOS 17+) for better accuracy

**macOS support:** ✅ Yes! VNFeaturePrintObservation works on macOS 10.15+
* macOS fingerprints ARE comparable to iOS fingerprints
* Same revision must be used across platforms
* Perfect for if Summa ever goes to macOS

**How to set revision in code:**
```swift
let request = VNGenerateImageFeaturePrintRequest()
request.revision = VNGenerateImageFeaturePrintRequestRevision2
```

#### Processing Pipeline

1. **Screenshot received via Share Extension**
   * Extension saves snapshot as it does currently
   * `screenshotImage` contains the image data (set by extension as it is now)
   * `fingerprintData` and `fingerprintRevision` are initially `nil`
   * No analysis happens in extension

2. **Image analysis in main Summa app**

   **Snapshot selection criteria:**
   * App analyzes snapshots where: `analysisState == pendingAnalysis`
   * This automatically means: has `sourceImage` data but needs analysis (fingerprint + value extraction + series matching)
   * Ensures we only process snapshots that haven't been analyzed yet

   **Processing order (critical - must follow this sequence):**

   **Analysis state transitions:**
   * Starts: `analysisState = pendingAnalysis` (snapshot has image but needs processing)
   * During processing: `analysisState = analyzing` (for all three phases)
   * After completion:
     * `analysisState = analysisCompleteFull` if value extracted AND series assigned
     * `analysisState = analysisCompletePartial` if value extracted but series NOT assigned

   a) **Phase 1: Generate all fingerprints**
   * For each selected snapshot, generate fingerprint using `VNGenerateImageFeaturePrintRequest` with Revision 2
   * Store `fingerprintData` and `fingerprintRevision` with the snapshot
   * Set `analysisState = analyzing`

   b) **Phase 2: Analyze images and extract values**
   * Extract value from screenshot (existing functionality)
   * Store `extractedValue`, `extractedText`, `analysisConfidence`, and `analysisDate`
   * Update snapshot `value` field with extracted value

   c) **Phase 3: Series matching (only for unassigned snapshots)**
   * **Critical rule: ONLY match snapshots where `series == nil`**
   * **Never change series assignment if already set (user-assigned or previously auto-assigned)**
   * For unassigned snapshots with fingerprints, run matching algorithm (see step 3 below)
   * If series auto-assigned: set `analysisState = analysisCompleteFull`
   * If series left as nil: set `analysisState = analysisCompletePartial`

3. **Series matching** (happens during image analysis in main app)
   * Collect all snapshots with fingerprints from all series
   * Filter to only snapshots with same fingerprint revision as the new snapshot
   * For each series, compare new fingerprint against ALL that series' snapshots using `computeDistance(_:to:)`
   * For each series, calculate average distance (or minimum distance) across all its snapshots
   * Apply distance threshold (note: this is an initial estimate and needs tuning with real data):
     * If best match distance < 0.25 (high confidence) → auto-assign to that series
     * If multiple series have distance < 0.25 → auto-assign to the closest one
     * If best match distance ≥ 0.25 → **leave series as nil** (current behavior)
   * No user interaction during matching process - fully automatic

### Design Decisions

**User interaction:** No user interaction during series matching. Process is fully automatic - either auto-assign with high confidence or leave series as nil for user to manually assign later.

**Series assignment immutability:** **Critical rule** - automatic logic NEVER changes a series assignment once set. Only snapshots with `series == nil` are eligible for auto-assignment. User-assigned or previously auto-assigned series are permanent until manually changed by user.

**Learning approach:** User teaches the system by manually assigning the first few snapshots to each series. System learns passively from these manual assignments.

**Processing order:** Three-phase sequential process: (1) Generate fingerprints, (2) Extract values from images, (3) Match series for unassigned snapshots only.

**Value magnitude disambiguation:** Not implemented in MVP. May struggle with visually identical UIs (same bank, different accounts).

**Performance/timing:** Fingerprint calculation happens during image analysis in main Summa app (not in Share Extension). Extension saves snapshot immediately with nil fingerprint fields.

**Edge cases (UI redesigns):** System will fail gracefully - either unable to assign (user teaches manually) or assigns incorrectly (user corrects and teaches). No special handling needed.

### Implementation Plan

**MVP Features:**

* Add `fingerprintData: Data?` and `fingerprintRevision: Int?` fields to `ValueSnapshot` model
* Implement three-phase image analysis workflow in main app:
  * Phase 1: Generate fingerprints for all selected snapshots
  * Phase 2: Extract values from screenshots
  * Phase 3: Match series (only for snapshots with `series == nil`)
* Use explicit revision (recommend Revision 2 for iOS 17+, hardcoded)
* Implement series matching algorithm:
  * **Critical:** Only process snapshots where `series == nil`
  * Compare against all snapshots in all series with matching revision
  * Calculate average/minimum distance per series
  * Auto-assign if best match < 0.25 threshold (pick closest if multiple match)
  * Leave as nil if no match meets threshold
* Store fingerprints with snapshots (automatic CloudKit sync)
* Trigger analysis when user opens app (select snapshots where `analysisState == pendingAnalysis`)
* Update `analysisState` appropriately: `analyzing` during processing, `analysisCompleteFull` or `analysisCompletePartial` after completion
* **Never** automatically change series once assigned (user or auto-assigned)

**Future Enhancements (Optional):**

* Track historical value ranges per series as tiebreaker for visually identical UIs
* Detect UI redesigns (sudden drop in match confidence) and prompt fingerprint refresh
* Adaptive confidence thresholds based on user correction frequency

### Testing Considerations

* Need test suite with diverse screenshot samples
* Should test: same bank different accounts, different banks, app redesigns
* Performance testing: fingerprint generation time, comparison time with 10 series
* Edge case: user has 10 series all from same bank (worst case for visual matching)

### Privacy & Security

* All processing happens on-device (Vision framework)
* No screenshots or fingerprints sent to external servers
* Fingerprints are perceptual hashes, not actual images (privacy-preserving)
* If synced via CloudKit, data stays in user's private iCloud database

---

## Managing State and Launching Background Processes

### Problem Statement

The current implementation uses a complex `analysisState` enum with many values (`pendingAnalysis`, `analyzing`, `analysisCompleteFull`, `analysisCompletePartial`, `analysisFailed`, `humanConfirmed`). This creates several problems:

1. **Over-complicated**: Too many states to reason about
2. **Tight coupling**: ContentView must understand internal processing states to decide what to trigger
3. **Unclear UI indicators**: Different colored icons and backgrounds are hard to interpret
4. **Inflexible**: Hard to add new processing steps

### Proposed Solution: Radical Simplification

**Core principle**: Replace complex state machine with simple rules:

* **Fingerprint generation**: Always runs if missing (even for human-confirmed snapshots) - enables future matching
* **Value extraction**: Only for snapshots without values that haven't been tried yet
* **Series matching**: Only for snapshots without assigned series

**Stop conditions**:
* Value extraction stops when: user manually sets value OR extraction was attempted
* Series matching stops when: user OR auto-match assigns series

#### Data Model Changes

**Remove**:
```swift
var analysisStateRaw: String  // Delete - too complex
var dataSourceRaw: String     // Delete - not needed
```

**Keep existing**:
```swift
var value: Double?
var series: Series?
var sourceImage: Data?
var fingerprintData: Data?
var fingerprintRevision: Int?
```

**Add**:
```swift
var valueExtractionAttempted: Bool = false  // Have we tried extracting value?
var humanConfirmed: Bool = false            // Has user explicitly saved/edited this snapshot?
```

**Human confirmation**: Set `humanConfirmed = true` when user saves snapshot via edit form (ValueSnapshotEditView)

---

#### Three Independent Processes

Each process is self-contained and decides internally which snapshots to process:

##### 1. Fingerprint Generation

**Service query** (internal to service):
```swift
#Predicate {
    $0.sourceImage != nil && $0.fingerprintData == nil
}
```

**Processing**:
* Generate fingerprint for ALL snapshots with images but no fingerprints
* Works on both new snapshots AND legacy data
* Safe to run repeatedly (idempotent)

**Failure**: Leaves `fingerprintData = nil`, will retry next time

---

##### 2. Value Extraction

**Service query** (internal to service):
```swift
#Predicate {
    $0.sourceImage != nil &&
    $0.value == nil &&
    $0.valueExtractionAttempted == false &&
    $0.humanConfirmed == false  // Don't extract if user confirmed empty value
}
```

**Processing**:
* Run OCR and extract monetary value
* Set `valueExtractionAttempted = true` (don't retry if failed)
* Store extracted value in `value` field

**Failure**: Sets `valueExtractionAttempted = true` with `value = nil` (tried but failed)

**Stop condition**: User saves snapshot (sets `humanConfirmed = true`)

---

##### 3. Series Matching

**Service query** (internal to service):
```swift
#Predicate {
    $0.sourceImage != nil &&
    $0.fingerprintData != nil &&
    $0.series == nil
}
```

**Processing**:
* Compare fingerprint against all series
* Auto-assign if distance < 0.25 threshold
* Safe to keep trying (matching is cheap, no harm in retrying)

**Stop condition**: Series is assigned (by auto-match OR by user)

---

### ContentView Integration: Dead Simple

**Core principle**: Don't count, don't check, don't decide - just trigger!

#### Trigger Point

`onChange(of: syncMonitor.lastImportDate)` - when CloudKit imports new data (from Share Extension)

#### Implementation

```swift
.onChange(of: syncMonitor.lastImportDate) { _, _ in
    Task {
        // Just call all three services in sequence
        // Each service decides internally what needs processing
        await analysisCoordinator.generateMissingFingerprints(modelContext: modelContext)
        await analysisCoordinator.extractPendingValues(modelContext: modelContext)
        await analysisCoordinator.matchUnassignedSeries(modelContext: modelContext)
    }
}
```

**That's it!** No counting, no state flags, no complex logic.

**Why this works**:
* Each service queries internally (see predicates above)
* If nothing needs processing, query returns empty → service does nothing
* Sequential execution ensures fingerprints exist before series matching
* Services are idempotent (safe to call repeatedly)

---

### ImageAnalysisCoordinator: Three Simple Methods

Each method contains its own query logic - no external counting needed:

```swift
/// Generate fingerprints for ALL snapshots with images but no fingerprints
func generateMissingFingerprints(modelContext: ModelContext) async {
    let descriptor = FetchDescriptor<ValueSnapshot>(
        predicate: #Predicate {
            $0.sourceImage != nil && $0.fingerprintData == nil
        }
    )
    guard let snapshots = try? modelContext.fetch(descriptor) else { return }

    for snapshot in snapshots {
        // Generate and store fingerprint
        // Silent failure OK - will retry next time
    }
}

/// Extract values from snapshots that haven't been tried yet
func extractPendingValues(modelContext: ModelContext) async {
    let descriptor = FetchDescriptor<ValueSnapshot>(
        predicate: #Predicate {
            $0.sourceImage != nil &&
            $0.value == nil &&
            $0.valueExtractionAttempted == false &&
            $0.humanConfirmed == false
        }
    )
    guard let snapshots = try? modelContext.fetch(descriptor) else { return }

    for snapshot in snapshots {
        snapshot.valueExtractionAttempted = true  // Mark as tried
        // Attempt value extraction
        // If success: snapshot.value = extractedValue
        // If failure: snapshot.value stays nil
    }
}

/// Match series for snapshots with fingerprints but no series
func matchUnassignedSeries(modelContext: ModelContext) async {
    let descriptor = FetchDescriptor<ValueSnapshot>(
        predicate: #Predicate {
            $0.sourceImage != nil &&
            $0.fingerprintData != nil &&
            $0.series == nil
        }
    )
    guard let snapshots = try? modelContext.fetch(descriptor) else { return }

    // Fetch all fingerprinted snapshots for comparison
    let allSnapshots = try? modelContext.fetch(FetchDescriptor<ValueSnapshot>(
        predicate: #Predicate { $0.fingerprintData != nil }
    ))

    for snapshot in snapshots {
        // Try to match series
        // If match found: snapshot.series = matchedSeries
        // If no match: leave nil (will retry next time)
    }
}
```

**Key insight**: Each method is self-sufficient - query + process in one place

---

### When Does `humanConfirmed` Get Set?

The `humanConfirmed` flag is set to `true` when the user explicitly saves a snapshot through the edit form:

**ValueSnapshotEditView**:
```swift
func saveSnapshot() {
    snapshot.humanConfirmed = true  // User explicitly saved/edited this
    // ... save to modelContext
}
```

**Important cases**:
* **User manually enters new snapshot**: `humanConfirmed = true` (no automatic processing)
* **User edits robot-created snapshot**: `humanConfirmed = true` (stop all automatic processing)
* **Robot creates snapshot via Share Extension**: `humanConfirmed = false` (allow automatic processing)

**Effect**:
* Once `humanConfirmed = true`, automatic value extraction stops (but fingerprint generation still runs)
* Series matching can still run (in case user wants to manually assign series later)
* Grey background disappears (snapshot is in final state)

---

### UI Simplification

**Goal**: Remove complex state indicators, keep it dead simple

#### Visual Indicators (ValueSnapshotListEntryView)

**Show only three things**:

1. **Series color indicator** (left side):
   * Colored circle showing which series this snapshot belongs to
   * Uses the series' configured color
   * Only shown if `series != nil`
   * Size: 12pt diameter

2. **Image icon** (right side):
   * Present if `sourceImage != nil`
   * No color coding, no spinner - just a simple photo icon
   * Icon: `photo` system image

3. **Row background**:
   * **Grey background** (`Color.gray.opacity(0.12)`): Robot-created snapshot (not yet confirmed by user)
   * **No background** (white/system): User-confirmed snapshot (user saved it explicitly)

**When to show grey background**:
```swift
var needsProcessing: Bool {
    // Simple rule: grey if not human confirmed
    return !humanConfirmed
}
```

**Rationale**: Keep it dead simple - the grey background indicates "this came from automation, you might want to review it"

**That's it!** No more:
* Blue/green/orange/red colored icons
* Spinning progress indicators
* State-dependent text
* Complex background logic

---

#### Series Indicator Visualization

**In ValueSnapshotListEntryView** (snapshot list rows):

The colored circle on the left side of each snapshot row serves as the **series identifier**:

* **Purpose**: Quick visual identification of which series a snapshot belongs to
* **Appearance**: Small filled circle (12pt) in the series' configured color
* **Behavior**:
  * Shown when `snapshot.series != nil` (series is assigned)
  * Hidden when `snapshot.series == nil` (no series assigned yet)
  * Color matches `SeriesManager.shared.colorFromHex(series.color)`

**Design rationale**:
* Provides instant visual scanning - users can quickly identify snapshots from the same series
* Consistent with series management UI where each series has its designated color
* No additional text/labels needed - the color is the identifier
* Works alongside auto-assignment: circle appears automatically when series is matched

**Example visual hierarchy** (left to right):
```
[🔴] Dec 12, 2025  |  Comdirect  |  $1,234.56  [📷]
     ↑                    ↑             ↑         ↑
  Series color      Series name    Value    Has image
```

---

### Migration & Legacy Data

**Existing snapshots** (before this feature):
* Have: `value`, `series`, `date`
* Missing: `fingerprintData`, `valueExtractionAttempted`

**What happens on first launch after update**:
1. CloudKit import triggers processing
2. `generateMissingFingerprints()` runs → adds fingerprints to all old snapshots
3. `extractPendingValues()` skips them (they have values)
4. `matchUnassignedSeries()` skips them (they have series)

**Result**: Legacy data gets fingerprints silently in background, everything else unchanged

---

### Summary: What Changed

**Before** (complex):
* 6-value `analysisState` enum
* ContentView counts and decides what to trigger
* Complex UI with 5+ different visual states

**After** (simple):
* Two flags: `humanConfirmed` (user saved it?) + `valueExtractionAttempted` (tried extracting?)
* Services self-query and self-execute
* UI shows: has image? needs processing (grey background)? Done.

**Benefits**:
* **Easier to understand**: No state machine to reason about
* **More maintainable**: Add new processing by adding new service method
* **Better UX**: Simple, clear visual feedback
* **Handles edge cases**: Works with legacy data, partial failures, retries

