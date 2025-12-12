# Accept Multiple Screenshots

## Overview
Currently we can share one screenshot with Summa via the Summa Share extension. This should be extended to accept multiple screenshots in a single share action.

## Current Implementation

The Share extension (`ShareViewController.swift`) currently:
- Accepts only 1 image (set via `NSExtensionActivationSupportsImageWithMaxCount: 1` in Info.plist)
- Processes the first attachment from `extensionContext?.inputItems.first?.attachments?.first`
- Extracts image data and EXIF metadata (date) from the image
- Creates a single `ValueSnapshot` with the screenshot using `ValueSnapshot.fromScreenshot()`
- Saves to SwiftData and completes the extension

Each snapshot is later processed by the main app for:
- Vision-based text recognition (OCR)
- Value extraction via Claude API
- Visual fingerprinting for series auto-assignment
- User confirmation/editing

## Proposed Changes

### 1. Info.plist Configuration
Change `NSExtensionActivationSupportsImageWithMaxCount` to support multiple images:
- **Option A**: Set specific limit (e.g., 10 or 20)
- **Option B**: Use `TRUEPREDICATE` for unlimited images

### 2. Processing Multiple Attachments
Modify `processSharedImage()` to iterate through all attachments:
```swift
// Instead of: extensionItem.attachments?.first
// Process: extensionItem.attachments (array)
```

### 3. Batch Snapshot Creation
Create multiple `ValueSnapshot` objects, one per image:
- Extract metadata (date) from each image
- Create snapshots in a batch
- Save all to SwiftData in a single transaction

## Architectural Options

### Option A: Sequential Processing (Simple)
**Implementation:**
- Loop through attachments one by one
- Load image → extract metadata → create snapshot → save
- Show single success/failure message after all complete

**Pros:**
- Simpler code, easier to debug
- Natural ordering preservation
- Lower memory usage (one image at a time)

**Cons:**
- Slower for large batches
- Extension may timeout for many images
- No progress feedback during processing

**Best for:** Small batches (2-5 images), simplicity

### Option B: Concurrent Processing (Fast)
**Implementation:**
- Use `TaskGroup` to process multiple images in parallel
- Load all images concurrently
- Batch insert all snapshots together
- Show progress indicator during processing

**Pros:**
- Much faster for large batches
- Better user experience with progress
- Efficient resource utilization

**Cons:**
- Higher memory usage (multiple images loaded)
- More complex error handling
- Potential memory pressure on older devices

**Best for:** Large batches (5+ images), performance-critical use cases

### Option C: Hybrid Approach
**Implementation:**
- Process images in small batches (e.g., 3-5 at a time)
- Show progress indicator
- Balance memory usage and speed

**Pros:**
- Good performance without excessive memory
- Progress feedback
- Handles large batches gracefully

**Cons:**
- Most complex implementation
- Need to tune batch size

**Best for:** Production use with unknown batch sizes

## UI/UX Considerations

### Success Feedback
Current: "Saved to Summa - Screenshot ready to process"

**Options for multiple:**
1. **Simple count**: "Saved 5 screenshots to Summa"
2. **Progress indicator**: Show live progress during processing
3. **Detailed summary**: "Saved 5 screenshots, 4 with dates, 1 without"

### Error Handling
**Scenarios:**
- Some images fail to load (corrupted data, unsupported format)
- Database save fails for some but not all
- Extension times out before completion

**Strategies:**
1. **All-or-nothing**: Fail if any image fails (rollback transaction)
2. **Best-effort**: Save what succeeds, report failures
3. **Retry logic**: Attempt to recover from transient errors

### Processing Time
Share extensions have limited execution time (~30 seconds on iOS):
- Need to estimate: ~1-2 seconds per image for loading + metadata extraction
- Safe batch size: 10-15 images
- For larger batches: Consider background processing or main app handoff

## Technical Considerations

### Memory Management
- Screenshots can be large (2-5 MB each)
- Loading 20 images = 40-100 MB memory spike
- Need to release image data after creating snapshots
- Consider autoreleasepool for memory cleanup

### CloudKit Sync
- Current implementation waits 0.5s after save for CloudKit export scheduling
- Multiple snapshots might need longer delay
- Alternative: Let main app handle sync (more reliable)

### Extension Lifecycle
- iOS may terminate extension aggressively
- Need robust handling of partial saves
- Consider: Mark snapshots with "batch ID" for cleanup/retry

### Date Extraction
- EXIF metadata varies by source (Photos app, camera, screenshot tool)
- Some images may have no date (use current date or nil?)
- Should preserve image order if no dates available

## Open Questions

### Limits and Constraints
1. **What's the maximum number of images we should support?**
   - 10? 20? Unlimited?
   - Consider: Extension timeout, memory, UX complexity
   - Recommendation: Start with 10, can increase later

2. **Should we impose a limit or trust iOS to handle it?**
   - iOS already limits via memory/time constraints
   - Explicit limit provides better UX

### User Experience
3. **How should we handle partial failures?**
   - Fail all vs. save what works?
   - Recommendation: Best-effort with summary message

4. **Do we need a progress indicator?**
   - Simple extensions typically don't show progress
   - But for 10+ images, users might wonder if it's frozen
   - Recommendation: Add for batches > 5 images

5. **Should we show which images succeeded/failed?**
   - Detailed error reporting vs. simple count
   - Recommendation: Simple count initially, detailed if needed

### Processing Strategy
6. **Sequential vs. concurrent processing?**
   - Recommendation: Start with sequential (Option A), optimize later if needed
   - Simpler code, fewer edge cases, sufficient for typical use

7. **Should we process in the extension or defer to main app?**
   - Current: Extension creates snapshots, main app processes them
   - Alternative: Extension just queues images, main app does everything
   - Recommendation: Keep current model, works well

### Data Integrity
8. **How do we handle duplicate images?**
   - Same image shared twice → two snapshots?
   - Check fingerprint before saving? (expensive in extension)
   - Recommendation: Allow duplicates, let user delete in main app

9. **Should we preserve selection order or sort by date?**
   - User selected in specific order (maybe meaningful)
   - But dates might be more logical
   - Recommendation: Preserve selection order, user can reorder in main app

### Series Assignment
10. **Should multiple screenshots go to the same series?**
    - Current: Each snapshot can be auto-assigned to different series via fingerprinting
    - Alternative: Batch assignment - all to last used series?
    - Recommendation: Keep current behavior (individual assignment)

## Implementation Plan

### Phase 1: Basic Multi-Image Support (MVP)
- [ ] Update Info.plist to accept 10 images
- [ ] Modify ShareViewController to process all attachments sequentially
- [ ] Update success message to show count
- [ ] Basic error handling (best-effort saves)
- [ ] Testing with 2, 5, 10 images

### Phase 2: Enhanced UX (Optional)
- [ ] Progress indicator for batches > 5
- [ ] More detailed success/failure reporting
- [ ] Memory optimization with autoreleasepool
- [ ] Handle edge cases (timeout, memory pressure)

### Phase 3: Performance Optimization (Future)
- [ ] Concurrent processing if needed
- [ ] Increase limit if demand exists
- [ ] Background processing for very large batches

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Extension timeout with many images | High | Limit to 10 images, optimize processing |
| Memory pressure causes crash | Medium | Use autoreleasepool, process sequentially |
| Partial saves create inconsistent state | Low | Each snapshot is independent, no issue |
| User confusion with success message | Low | Clear messaging with count |
| CloudKit sync delays/failures | Low | Existing retry mechanisms handle this |

## Testing Scenarios

1. **Single image** - Should work exactly as before
2. **2-5 images** - Typical use case, should be fast and seamless
3. **10 images** - Maximum supported, should complete within timeout
4. **Mixed content** - Some valid images, some corrupted - handle gracefully
5. **Large images** - Screenshots from iPad Pro - memory handling
6. **No dates** - Images without EXIF data - use current time
7. **Extension termination** - Force quit during processing - no corruption

## Success Criteria

- ✅ User can share 2-10 screenshots in a single action
- ✅ All valid images are saved as separate snapshots
- ✅ Success message clearly indicates how many were saved
- ✅ Extension completes within iOS timeout limits
- ✅ No memory crashes or data corruption
- ✅ Existing single-image workflow unchanged

## Related Features

- Visual fingerprinting (Spec 12) - Works per-snapshot, unaffected
- OCR and value extraction - Main app processes each snapshot independently
- Series auto-assignment - Each snapshot can match different series