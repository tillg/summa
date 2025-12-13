# Accept Multiple Screenshots

## Overview

Currently we can share one screenshot with Summarum via the Summarum Share extension. This should be extended to accept multiple screenshots (up to 10) in a single share action.

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

## Design Decisions

### Maximum Batch Size: 10 Images

Share extensions have limited execution time (~30 seconds on iOS). With ~1-2 seconds per image for loading and metadata extraction, we'll support up to **10 images per batch**.

**Implementation:**
- Store constant in global variables file (e.g., `Constants.swift` or similar)
- Set `NSExtensionActivationSupportsImageWithMaxCount: 10` in Info.plist

### Processing Strategy: Sequential

We'll use **sequential processing** (process one image at a time):
- Simpler code, easier to debug
- Lower memory usage
- Natural ordering preservation
- Sufficient performance for 10 images

We'll optimize to concurrent processing only if performance becomes an issue.

### User Feedback

**Progress Indicator:** Display a progress indicator while processing images

**Success Message:** Show simple count after completion:
- Single image: "Saved to Summarum - Screenshot ready to process" (unchanged)
- Multiple images: "Saved 5 screenshots to Summarum"

### Error Handling: Best-Effort

Try to save all images, report results at the end:
- If all succeed: "Saved 10 screenshots to Summarum"
- If some fail: "Saved 7 of 10 screenshots to Summarum"
- If all fail: Show error message as before

Each `ValueSnapshot` is independent, so partial saves are acceptable.

### Data Processing

**Date Extraction:** Process each image exactly as we do for single images - extract EXIF date if available, otherwise use `nil`.

**Image Order:** Take images as they come from the system, no sorting or reordering.

**Series Assignment:** Each snapshot processed independently by main app - each can be assigned to different series via fingerprinting.

**Duplicate Handling:** Allow duplicates for now - we'll tackle deduplication in a future spec.

### Technical Approach: Start Simple, Fix If Needed

For MVP, we'll use the current implementation patterns and optimize only if we encounter issues:

**Memory Management:** Process sequentially to minimize memory usage. Add `autoreleasepool` only if we see memory pressure.

**CloudKit Sync:** Keep existing 0.5s delay after save. Adjust only if sync issues arise with multiple snapshots.

**Extension Lifecycle:** Trust iOS to give us enough time for 10 images. Add batch tracking only if we see termination issues.

## Implementation Changes

### 1. Create Constants File (if not exists)

```swift
// Constants.swift or AppConfig.swift
struct ShareExtensionConfig {
    static let maxScreenshotsPerBatch = 10
}
```

### 2. Update Info.plist

Change:
```xml
<key>NSExtensionActivationSupportsImageWithMaxCount</key>
<integer>10</integer>
```

### 3. Refactor ShareViewController

**Rename method:** `processSharedImage()` → `processSharedImages()`

**Core changes:**
```swift
private func processSharedImages() {
    guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
          let attachments = extensionItem.attachments,
          !attachments.isEmpty else {
        completeRequest(success: false)
        return
    }

    let imageAttachments = attachments.filter {
        $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
    }

    // Show progress indicator
    showProgressIndicator(total: imageAttachments.count)

    // Process sequentially
    Task {
        let results = await processAttachmentsSequentially(imageAttachments)
        await showResultsAndComplete(results)
    }
}

private func processAttachmentsSequentially(_ attachments: [NSItemProvider]) async -> [ProcessingResult] {
    var results: [ProcessingResult] = []

    for (index, provider) in attachments.enumerated() {
        updateProgress(current: index + 1)
        let result = await processAttachment(provider)
        results.append(result)
    }

    return results
}

private func processAttachment(_ provider: NSItemProvider) async -> ProcessingResult {
    // Extract image data and date (existing logic)
    // Create snapshot
    // Save to SwiftData
    // Return success/failure
}
```

### 4. Add Progress UI

```swift
private var progressView: UIView?
private var progressLabel: UILabel?

private func showProgressIndicator(total: Int) {
    // Create simple progress view with label
    // "Processing 1 of 10..."
}

private func updateProgress(current: Int) {
    // Update label: "Processing 2 of 10..."
}
```

### 5. Update Completion Message

```swift
private func showResultsAndComplete(_ results: [ProcessingResult]) {
    let successCount = results.filter { $0.success }.count
    let totalCount = results.count

    let message: String
    if totalCount == 1 {
        message = successCount == 1 ?
            "Screenshot ready to process" :
            "Failed to save screenshot"
    } else if successCount == totalCount {
        message = "Saved \(successCount) screenshots to Summarum"
    } else if successCount > 0 {
        message = "Saved \(successCount) of \(totalCount) screenshots to Summarum"
    } else {
        message = "Failed to save screenshots"
    }

    let alert = UIAlertController(
        title: successCount > 0 ? "Saved to Summarum" : "Error",
        message: message,
        preferredStyle: .alert
    )
    // ... complete request
}
```

## Implementation Plan

### Phase 1: MVP (This Implementation)
- [x] Create or update Constants file with `maxScreenshotsPerBatch = 10`
- [ ] Update Info.plist to accept 10 images
- [ ] Rename `processSharedImage()` to `processSharedImages()`
- [ ] Implement sequential processing loop for all attachments
- [ ] Add progress indicator UI
- [ ] Update completion messages with count
- [ ] Test with 1, 2, 5, and 10 images

### Phase 2: Optimization (If Needed)
- [ ] Add `autoreleasepool` if memory issues occur
- [ ] Adjust CloudKit sync delay if needed
- [ ] Add concurrent processing if performance is insufficient
- [ ] Handle extension timeout gracefully

### Future Enhancements (Separate Specs)
- [ ] Duplicate detection
- [ ] Increase limit beyond 10
- [ ] Background processing for very large batches

## Testing Scenarios

1. **Single image** - Should work exactly as before with existing message
2. **2-5 images** - Typical use case, show progress and count
3. **10 images** - Maximum supported, verify completion within timeout
4. **Mixed valid/invalid** - Some valid images, some corrupted files
5. **Large images** - iPad Pro screenshots, verify memory handling
6. **No dates** - Images without EXIF data - should use `nil` as before
7. **Multiple series** - Verify each snapshot can be assigned to different series by main app

## Success Criteria

- ✅ User can share 2-10 screenshots in a single action
- ✅ Progress indicator shows during processing
- ✅ Success message clearly indicates count (e.g., "Saved 5 screenshots to Summarum")
- ✅ Best-effort handling: save what succeeds, report failures
- ✅ Extension completes within iOS timeout limits
- ✅ No memory crashes or data corruption
- ✅ Single-image workflow unchanged (backward compatible)

## Related Features

- Visual fingerprinting (Spec 12) - Works per-snapshot, unaffected by batching
- OCR and value extraction - Main app processes each snapshot independently
- Series auto-assignment - Each snapshot can match different series
