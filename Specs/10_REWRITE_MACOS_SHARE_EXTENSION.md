# Rewrite macOS Share Extension with NSViewController

## Problem Statement

The macOS share extension appears in the system share menu but **no code executes** when selected (December 11, 2025):

**Symptoms:**
- ❌ No `viewDidLoad()` execution
- ❌ No log entries (Console or file-based)
- ❌ No UI appears when extension is selected
- ❌ No data is saved to SwiftData
- ✅ Extension **does appear** in share menu (registered successfully)
- ✅ Extension target builds without errors
- ✅ All entitlements and configuration appear correct

**Current Status:**
- ✅ **iOS share extension works perfectly** - CloudKit sync, data saving, UI all functional
- ❌ **macOS share extension completely broken** - zero code execution despite being visible

## Root Cause Analysis

### PRIMARY CAUSE: `SLComposeServiceViewController` is iOS-Only

**Current Summa macOS Implementation:**
```swift
// Summa/Summa Share Extension macOS/ShareViewController.swift
import Social  // ❌ iOS-only framework
import Cocoa
import SwiftData

class ShareViewController: SLComposeServiceViewController {  // ❌ iOS-only class
    override func viewDidLoad() {
        // This code NEVER runs on macOS
    }
}
```

**The Fundamental Problem:**

`SLComposeServiceViewController` is part of the **Social framework**, which:
- Does **not exist on macOS** at runtime
- Is an **iOS-only** class designed for iOS share sheets
- Cannot be instantiated by the macOS extension system
- Causes the extension to fail silently without errors

When macOS tries to instantiate the view controller, it cannot find `SLComposeServiceViewController`, preventing the extension from loading entirely. No code runs because the view controller itself cannot be created.

### Evidence from Working Implementation

**open-in-dia macOS ShareViewController (working reference):**
```swift
// /Users/tgartner/git/open-in-dia/Open in Dia share extension/ShareViewController.swift
import Cocoa  // ✅ macOS framework
// NO Social framework import

class ShareViewController: NSViewController {  // ✅ macOS class
    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedItems()  // Code successfully executes
    }
}
```

**Key Differences:**

| Aspect | Summa (Broken) | open-in-dia (Working) |
|--------|---------------|----------------------|
| Base Class | `SLComposeServiceViewController` | `NSViewController` |
| Framework | `import Social` | `import Cocoa` |
| Availability | iOS only | macOS native |
| UI Definition | MainInterface.storyboard | ShareViewController.xib |
| Result | Silent failure, no execution | Works perfectly |

### Secondary Issues

1. **Storyboard vs XIB Configuration:**
   - Summa uses `NSExtensionMainStoryboard` with MainInterface.storyboard
   - open-in-dia uses XIB file (ShareViewController.xib)
   - XIBs are more reliable for macOS extension view controller loading
   - Storyboards on macOS extensions can have instantiation issues

2. **Empty UI (Not Critical):**
   - Current storyboard has no UI elements (just blank 450x300 view)
   - Even if the extension loaded, users would see nothing
   - Silent processing requires proper lifecycle handling

3. **Different Lifecycle Methods:**
   - `SLComposeServiceViewController` uses `didSelectPost()` for action handling
   - `NSViewController` uses standard `viewDidLoad()` for initialization
   - Code structured for iOS lifecycle won't work on macOS base class

## Reference Implementation: open-in-dia Project

### How open-in-dia Successfully Handles macOS Shares

**File:** `/Users/tgartner/git/open-in-dia/Open in Dia share extension/ShareViewController.swift`

**Architecture:**
```swift
class ShareViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedItems()
    }

    private func handleSharedItems() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }

        for item in items {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier,
                                     options: nil) { [weak self] (item, error) in
                        guard let self = self else { return }

                        // Process the item (URL, NSImage, Data)
                        // Perform business logic
                        // Complete request

                        self.completeRequest()
                    }
                }
            }
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
```

**Key Patterns to Adopt:**
1. Process shared items immediately in `viewDidLoad()` via helper method
2. Use `extensionContext?.inputItems` to access shared content
3. Use `loadItem(forTypeIdentifier:options:)` with completion handler
4. Call `completeRequest(returningItems:completionHandler:)` when done
5. No UI presentation - process silently in background

**Info.plist Configuration:**
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <string>TRUEPREDICATE</string>  <!-- Accepts all content types -->
    </dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
    <!-- NO NSExtensionMainStoryboard key - XIB loaded automatically -->
</dict>
```

**XIB Configuration:**
- Minimal ShareViewController.xib in Base.lproj
- File's Owner set to ShareViewController class
- View outlet connected to NSView
- Simple UI with Send/Cancel buttons (optional for Summa)

## Solution: Convert to NSViewController with XIB

### Approach

Replace the iOS-only `SLComposeServiceViewController` architecture with macOS-native `NSViewController` following the proven open-in-dia pattern.

**Strategy:**
- **Silent background processing** - no UI shown to user
- **XIB-based view loading** - more reliable than storyboards for extensions
- **Immediate processing** - handle share in `viewDidLoad()`
- **Keep all business logic** - SwiftData, CloudKit, image processing unchanged

### Architecture Changes

```
Current (Broken):
ShareViewController (SLComposeServiceViewController) → iOS-only, fails to instantiate
    ↓ (NEVER CALLED)
viewDidLoad() → Create model container
    ↓ (NEVER CALLED)
didSelectPost() → Process image, save to SwiftData

New (Working):
ShareViewController (NSViewController) → macOS-native, instantiates correctly
    ↓
viewDidLoad() → Create model container → processSharedImage()
    ↓
processSharedImage() → Load image → saveToSwiftData()
    ↓
saveToSwiftData() → Insert, save, 0.5s delay → completeRequest()
```

## Implementation Plan

### Step 1: Update ShareViewController Base Class

**File:** `Summa/Summa Share Extension macOS/ShareViewController.swift`

**Changes:**
1. **Remove** `import Social`
2. **Change** base class from `SLComposeServiceViewController` to `NSViewController`
3. **Move** `didSelectPost()` logic to `processSharedImage()` called from `viewDidLoad()`
4. **Keep** all existing business logic:
   - Model container creation via `ModelContainerFactory.createSharedContainer()`
   - Image loading and data extraction
   - SwiftData insert and save
   - CloudKit export delay (0.5s)
   - File-based logging

**New Structure:**
```swift
//
//  ShareViewController.swift
//  Summa Share Extension (macOS)
//

import Cocoa
import SwiftData
import UniformTypeIdentifiers

class ShareViewController: NSViewController {

    private var modelContainer: ModelContainer?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Log execution to verify code runs
        writeLog("🍎 macOS Extension viewDidLoad called!")

        // Create shared model container
        do {
            modelContainer = try ModelContainerFactory.createSharedContainer()
            writeLog("✅ Model container created")
        } catch {
            writeLog("❌ Error creating container: \(error)")
            completeRequest(success: false)
            return
        }

        // Process shared image immediately
        processSharedImage()
    }

    private func processSharedImage() {
        writeLog("📤 processSharedImage called - starting share processing")

        guard let modelContainer = modelContainer else {
            writeLog("❌ No model container")
            completeRequest(success: false)
            return
        }

        // Get the shared image
        if let item = extensionContext?.inputItems.first as? NSExtensionItem,
           let provider = item.attachments?.first,
           provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {

            writeLog("📷 Loading image...")

            provider.loadItem(forTypeIdentifier: UTType.image.identifier,
                            options: nil) { [weak self] (item, error) in
                guard let self = self else { return }

                if let error = error {
                    self.writeLog("❌ Error loading image: \(error)")
                    self.completeRequest(success: false)
                    return
                }

                var imageData: Data?

                // Handle different image item types
                if let url = item as? URL {
                    imageData = try? Data(contentsOf: url)
                } else if let image = item as? NSImage {
                    if let tiffData = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData) {
                        imageData = bitmap.representation(using: .jpeg,
                                                         properties: [.compressionFactor: 0.8])
                    }
                } else if let data = item as? Data {
                    imageData = data
                }

                guard let imageData = imageData else {
                    self.writeLog("❌ Could not get image data")
                    self.completeRequest(success: false)
                    return
                }

                self.writeLog("✅ Image loaded, size: \(imageData.count) bytes")

                // Create and save snapshot
                let snapshot = ValueSnapshot.fromScreenshot(imageData, date: Date())

                Task {
                    do {
                        let context = modelContainer.mainContext
                        context.insert(snapshot)
                        try context.save()

                        self.writeLog("✅ Snapshot saved!")

                        // Give CloudKit time to export (critical for sync)
                        try? await Task.sleep(for: .seconds(0.5))

                        await MainActor.run {
                            self.completeRequest(success: true)
                        }
                    } catch {
                        self.writeLog("❌ Error saving: \(error)")
                        await MainActor.run {
                            self.completeRequest(success: false)
                        }
                    }
                }
            }
        } else {
            writeLog("❌ No image attachment found")
            completeRequest(success: false)
        }
    }

    private func completeRequest(success: Bool) {
        writeLog(success ? "✅ Completing request successfully" : "❌ Completing request with failure")
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func writeLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(),
                                                     dateStyle: .none,
                                                     timeStyle: .medium)
        let logLine = "[🍎 \(timestamp)] \(message)\n"

        // Write to shared App Group log file
        if let logURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.grtnr.Summa")?
            .appendingPathComponent("extension-debug.log") {

            if let data = logLine.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        try? fileHandle.close()
                    }
                } else {
                    try? data.write(to: logURL)
                }
            }
        }

        // Also print to console
        print(logLine)
    }
}
```

**Key Changes from Current Code:**
- Base class: `NSViewController` (was `SLComposeServiceViewController`)
- Import: `Cocoa` only (removed `Social`)
- Lifecycle: All processing in `viewDidLoad()` → `processSharedImage()` (no `didSelectPost()`)
- Image type: `NSImage` (was implicit, now explicit)
- Log prefix: 🍎 emoji to identify macOS logs

**Unchanged (Keep Working):**
- Model container creation pattern
- Image data extraction logic
- SwiftData operations
- CloudKit 0.5s delay
- File-based logging approach

### Step 2: Update Info.plist Configuration

**File:** `Summa/Summa Share Extension macOS/Info.plist`

**Remove the `NSExtensionMainStoryboard` key:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>NSExtensionActivationRule</key>
            <dict>
                <key>NSExtensionActivationSupportsImageWithMaxCount</key>
                <integer>1</integer>
            </dict>
        </dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.share-services</string>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
        <!-- REMOVE THIS LINE: <key>NSExtensionMainStoryboard</key><string>MainInterface</string> -->
    </dict>
</dict>
</plist>
```

**Why:**
- Without `NSExtensionMainStoryboard`, the system automatically looks for a XIB file matching the principal class name
- `ShareViewController` class → looks for `ShareViewController.xib`
- More reliable loading mechanism for macOS extensions

### Step 3: Create Minimal ShareViewController.xib

**File:** `Summa/Summa Share Extension macOS/Base.lproj/ShareViewController.xib`

**Purpose:** Provide a minimal view for the extension to instantiate, even though no UI will be shown.

**Creation Steps:**

1. **In Xcode:** File → New → File → View (under macOS → User Interface)
2. **Name:** `ShareViewController` (do NOT include .xib extension when prompted)
3. **Save location:** `Summa/Summa Share Extension macOS/Base.lproj/` directory
4. **Target membership:** Check "Summa Share Extension macOS" only

**XIB Configuration:**

1. Open `ShareViewController.xib` in Interface Builder
2. **Delete the default "View" object** if one exists (we'll add our own)
3. **Select "File's Owner"** in the left panel (document outline)
4. **In Identity Inspector** (right panel):
   - Custom Class: `ShareViewController`
   - Module: `Summa_Share_Extension_macOS`
5. **Add NSView:**
   - Open Object Library (Cmd+Shift+L)
   - Drag "View" (NSView) into the document outline
   - Size: Set to 1x1 pixels (we won't show it)
6. **Connect view outlet:**
   - Control-drag from "File's Owner" to the NSView
   - Select "view" outlet in the popup
7. **Verify:** File's Owner → view outlet should show connection to "View"

**Result:** Minimal XIB that allows the extension to instantiate correctly without displaying UI.

### Step 4: Update Build Phases

**In Xcode project - Summa Share Extension macOS target:**

**1. Compile Sources:**
- ✅ Should contain: `ShareViewController.swift`
- ✅ Verify all shared model/utility files are also listed

**2. Copy Bundle Resources:**
- ✅ **ADD:** `ShareViewController.xib` (the new file)
- ✅ Keep: `icon.icns`
- ❌ **REMOVE:** `MainInterface.storyboard` (no longer needed)
- Check: `Base.lproj` folder should contain only XIB file

**3. Code Signing:**
- ✅ Verify entitlements file path: `Summa Share Extension macOS/Summa Share Extension macOS.entitlements`
- ✅ Verify signing identity is set

**How to update:**
1. Select "Summa Share Extension macOS" target in Xcode
2. Go to "Build Phases" tab
3. Expand "Copy Bundle Resources"
4. Use + button to add ShareViewController.xib
5. Select MainInterface.storyboard and press - button to remove
6. Clean build folder (⇧⌘K) after making changes

### Step 5: Clean and Rebuild

**Actions (in order):**

1. **Clean build folder** in Xcode: Product → Clean Build Folder (⇧⌘K)

2. **Delete derived data:**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Summa-*
   ```

3. **Kill running extension processes:**
   ```bash
   # Reset extension registration
   pluginkit -r /Users/tgartner/git/Summa/Summa/build/Debug/Summa.app

   # Kill any running extension processes
   killall -9 "Summa Share Extension macOS" 2>/dev/null || true

   # Kill system sharing services
   killall -9 sharingd 2>/dev/null || true
   ```

4. **Build and run Summa.app:**
   - Select "Summa" scheme
   - Select "My Mac" as destination
   - Product → Run (⌘R)

5. **Verify extension registration:**
   ```bash
   pluginkit -m -v | grep Summa
   ```

   Expected output should show:
   ```
   + com.grtnr.Summa.Summa-Share-Extension-macOS(1.0)
   ```

### Step 6: Testing

**Test Procedure:**

1. **Launch Summa.app** on macOS (⌘R in Xcode)

2. **Open Photos.app**

3. **Select an image**

4. **Click Share button** in toolbar

5. **Select "Summa"** from share menu

6. **Verify logs appear:**
   ```bash
   # Open Console.app
   # Filter: process:Summa OR process:com.grtnr.Summa
   # Look for: "🍎 macOS Extension viewDidLoad called!"
   ```

7. **Check file log:**
   ```bash
   cat ~/Library/Group\ Containers/group.com.grtnr.Summa/extension-debug.log
   ```

   Expected log entries:
   ```
   [🍎 HH:MM:SS] 🍎 macOS Extension viewDidLoad called!
   [🍎 HH:MM:SS] ✅ Model container created
   [🍎 HH:MM:SS] 📤 processSharedImage called - starting share processing
   [🍎 HH:MM:SS] 📷 Loading image...
   [🍎 HH:MM:SS] ✅ Image loaded, size: XXXXX bytes
   [🍎 HH:MM:SS] ✅ Snapshot saved!
   [🍎 HH:MM:SS] ✅ Completing request successfully
   ```

8. **Verify in main app:**
   - Open Summa.app
   - Check that new snapshot appears in list
   - Verify image is visible
   - Confirm date/time is correct

9. **Verify CloudKit sync (if multi-device):**
   - Wait 5 seconds
   - Open Summa on iOS device
   - Confirm snapshot appears automatically

**Success Criteria:**
- ✅ Logs appear in Console and file
- ✅ Snapshot saved to SwiftData
- ✅ Image data preserved correctly
- ✅ CloudKit sync occurs (if configured)
- ✅ Extension completes without crashes

## Critical Files

### Must Modify:
- `Summa/Summa Share Extension macOS/ShareViewController.swift` - Change base class to NSViewController
- `Summa/Summa Share Extension macOS/Info.plist` - Remove NSExtensionMainStoryboard key

### Must Create:
- `Summa/Summa Share Extension macOS/Base.lproj/ShareViewController.xib` - New XIB file for view loading

### Must Remove (from build phases):
- `Summa/Summa Share Extension macOS/Base.lproj/MainInterface.storyboard` - No longer used

### Keep Unchanged:
- `Summa/Summa Share Extension macOS/Summa Share Extension macOS.entitlements` - Already correct
- `Summa/Utils/ModelContainerFactory.swift` - Already correct
- All model files (ValueSnapshot.swift, Series.swift) - Already correct

### Reference (for comparison):
- `/Users/tgartner/git/open-in-dia/Open in Dia share extension/ShareViewController.swift` - Working macOS implementation

## Expected Outcome

After implementing these changes:

### Immediate Results:
- ✅ Extension code will execute (viewDidLoad will be called)
- ✅ Logs will appear in Console and file-based log
- ✅ Images will be saved to SwiftData
- ✅ CloudKit sync will trigger automatically

### User Experience:
- User shares image from Photos → Summa
- Brief system spinner appears
- Extension processes in background (no UI shown)
- Extension completes automatically
- Snapshot appears in main Summa app immediately
- If multi-device: snapshot syncs to other devices within seconds

### Technical Verification:
- NSViewController instantiates correctly (unlike SLComposeServiceViewController)
- All business logic executes as designed
- CloudKit 0.5s delay allows export scheduling
- macOS extension matches iOS functionality

### Platform Parity:
- ✅ iOS share extension: Working (already)
- ✅ macOS share extension: Working (after this fix)
- ✅ CloudKit sync: Working from both platforms
- ✅ Multi-device workflow: Complete end-to-end

## Benefits of This Approach

1. **Uses macOS-native framework:** `NSViewController` is the correct base class for macOS extensions
2. **Proven pattern:** Follows open-in-dia's working implementation
3. **Reliable loading:** XIB files work more consistently than storyboards for extension view controllers
4. **Silent processing:** No UI needed - processes in background like iOS version
5. **Minimal changes:** Only architectural changes, business logic unchanged
6. **Maintains iOS parity:** Same functionality, same CloudKit sync behavior
7. **Debuggable:** File-based logs provide visibility into execution

## Architectural Decision

**Chosen approach:** XIB-based NSViewController with silent background processing

**Rationale:**
- Directly addresses root cause (iOS-only base class)
- Follows proven working implementation (open-in-dia)
- More reliable than storyboard approach
- Simpler than showing UI (which isn't needed)
- Maintains consistency with iOS extension behavior

**Alternatives considered:**
1. **Keep SLComposeServiceViewController** - Not viable, iOS-only
2. **Use storyboard with NSViewController** - Less reliable than XIB
3. **Programmatic UI without XIB/storyboard** - More complex, no benefit
4. **Show UI to user** - Unnecessary, silent processing preferred

**Decision:** XIB + NSViewController + silent processing

---

## Implementation Status

**Status:** Ready to implement

**Estimated effort:** ~30 minutes
- 10 min: Update ShareViewController.swift code
- 10 min: Create ShareViewController.xib in Xcode
- 5 min: Update Info.plist and build phases
- 5 min: Clean, build, test

**Risk level:** Low
- All changes are well-defined
- Following proven working pattern
- iOS extension unaffected (separate target)
- Can revert easily if needed

**Next steps:** Proceed with implementation following the plan above.
