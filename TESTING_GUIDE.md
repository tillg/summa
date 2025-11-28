# Testing Guide

Quick test procedure to verify core functionality across iOS, iPad, and macOS.

## Prerequisites
- Clean app install or existing data
- Test screenshots available in Photos app (iOS/iPad only)

## Test Procedure

### 1. Basic Data Entry
1. Launch Summa
2. Tap "+" button � Add a value snapshot
3. Verify: Series picker shows "Default" (or existing series)
4. Enter value: 1000, select date, tap Save
5. Verify: Entry appears in list with correct date and value
6. Verify: Chart displays the data point

### 2. Series Management
1. Tap "Manage Series" button
2. Tap "+" � Create new series (e.g., "Savings")
3. Choose a color, tap Save
4. Verify: New series appears in list
5. Add another value snapshot using the new series
6. Verify: Chart shows multiple colored lines
7. Tap series chip in chart legend to hide/show lines
8. Verify: Lines toggle on/off correctly

### 3. Time Period Filtering
1. Add snapshots with different dates (e.g., today, 1 week ago, 1 month ago)
2. Switch between Week/Month/Year/All tabs
3. Verify: Chart filters data correctly for each period
4. Verify: List shows all entries regardless of chart filter

### 4. Screenshot Attachment (Existing Feature)
1. Open an existing value snapshot
2. Tap camera icon � Select photo from library
3. Verify: Thumbnail appears
4. Tap thumbnail to view full screen
5. Save and verify screenshot persists

### 5. Screenshot Analysis - Share Extension (iOS/iPad Only)
1. Open Photos app
2. Select a screenshot of banking/financial app showing a monetary value
3. Tap Share button � Select "Summa"
4. Verify: "Saved to Summa / Screenshot ready to process" message appears
5. Return to Summa app immediately
6. **Verify Analysis States** (watch for 10 seconds):
   - Entry appears with `[PENDING]` state label, gray background, question mark icon, photo icon
   - After ~10 seconds: Changes to `[ANALYZING]` with spinner icon
   - After analysis: Changes to `[PARTIAL]` (if no series) or `[FULL]` (if series detected)
   - Background remains gray for PARTIAL/FULL states
   - Background is light gray (0.08 opacity) for FULL state
7. **Verify Auto-Extracted Value**:
   - Tap the analyzed entry
   - Verify: Screenshot is visible
   - Verify: Value field is pre-populated with extracted amount
   - Verify: Series is empty (for PARTIAL) or populated (for FULL)
8. **Complete Entry**:
   - Select a series (if PARTIAL)
   - Optionally adjust the value if incorrect
   - Tap Save
9. **Verify Human Confirmation**:
   - Entry changes to `[HUMAN]` state
   - Background becomes white (no background)
   - Series color dot appears on left
   - Entry appears on chart

### 5a. Screenshot Analysis - Failed State
1. Share a non-banking screenshot (e.g., meme, landscape photo)
2. Return to Summa
3. Verify: Entry shows `[FAILED]` with double question mark icon (red)
4. Verify: Gray background
5. Tap entry and manually enter data
6. Verify: Converts to `[HUMAN]` with white background after save

### 5b. Screenshot Analysis - In-App Photo Selection
1. Tap "+" to add new entry
2. Tap "Attach Screenshot" under Screenshot section
3. Select a banking screenshot from Photos
4. Tap Save without entering value
5. Verify: Analysis triggers automatically
6. Verify: Same state progression as Share Extension flow

### 6. Series Deletion
1. In Series Management, swipe left on a series
2. Tap Delete
3. Enter series name to confirm
4. Verify: Series and all its snapshots are deleted
5. Verify: Chart updates accordingly

### 7. CloudKit Sync (Optional - requires iCloud)
1. Add data on one device
2. Wait 30 seconds
3. Open app on another device signed into same iCloud account
4. Verify: Data appears on second device

## Expected Results
- All CRUD operations work smoothly
- Chart renders correctly with multiple series
- **Screenshot analysis automatically extracts monetary values**
- **State transitions visible with proper backgrounds and icons**
- **Failed analyses handled gracefully without loops**
- Data persists across app restarts
- No crashes or data loss
- UI responds appropriately on each platform (iPhone/iPad/macOS)

## Platform-Specific Notes

**iOS/iPad:**
- Share extension available
- Touch interactions
- Swipe gestures work

**macOS:**
- No share extension (not applicable)
- Mouse/trackpad interactions
- Menu commands available (File � Add Value Snapshot, etc.)
- Window resizing works properly

## Known Limitations
- Share extension only processes images (ignores other content types)
- Maximum 10 series enforced
- Screenshot analysis extracts values only (no series/date detection yet)
- Analysis accuracy depends on screenshot quality and text clarity
- Currency format detection supports US, European, and Swiss formats
- Very small text (<10pt) may not be recognized

## Debug Features (DEBUG builds only)
- State labels shown in purple: `[PENDING]`, `[ANALYZING]`, `[PARTIAL]`, `[FULL]`, `[FAILED]`, `[HUMAN]`
- 10-second delay before analysis (to observe state transitions)
- Console logging for analysis events and state changes
- Remove these in production builds
