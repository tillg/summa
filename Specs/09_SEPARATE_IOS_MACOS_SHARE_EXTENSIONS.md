# Separate iOS and macOS Share Extensions

## Problem Statement

The current share extension architecture has iOS-only UI dependencies that prevent macOS support:

**Current state (December 2025):**

- ✅ Main app (`SummaApp.swift`) supports both iOS and macOS with `#if os(macOS)` conditionals
- ✅ `ModelContainerFactory` successfully shares CloudKit configuration between app and extension
- ✅ iOS share extension syncs data to CloudKit
- ❌ Share extension (`ShareViewController.swift`) uses UIKit, which is iOS-only
- ❌ No macOS share extension exists

**UIKit dependencies blocking macOS:**

```swift
// Summa Share Extension/ShareViewController.swift
import UIKit  // ❌ iOS-only, no macOS equivalent

class ShareViewController: UIViewController {  // ❌ UIKit class
    private func completeRequest(success: Bool) {
        let alert = UIAlertController(...)  // ❌ UIKit class
        // ...
    }
}
```

**Why unified extension is problematic:**

Attempting to handle both platforms with `#if os()` conditionals in the share extension would require:

- Dual imports: `#if os(iOS) import UIKit #else import AppKit #endif`
- Dual class inheritance: `#if os(iOS) UIViewController #else NSViewController #endif`
- Dual UI APIs throughout: `UIAlertController` vs `NSAlert`, `UIImage` vs `NSImage`, etc.
- Results in unreadable, hard-to-maintain code

## Recommended Solution: Separate Extension Targets

Create **two separate app extension targets** instead of one unified extension:

1. **Summa Share Extension (iOS)** - UIKit-based (current, rename only)
2. **Summa Share Extension (macOS)** - AppKit-based (NEW)

### Architecture

```
┌─────────────────────────────────────────────────┐
│              Summa.app                          │
│      (Universal: iOS + macOS)                   │
│  Uses: #if os(macOS) conditionals               │
└─────────────────────────────────────────────────┘

        ┌──────────────────────────┐
        │   Shared Code (Both)     │
        │                          │
        │ • ModelContainerFactory  │
        │ • ValueSnapshot.swift    │
        │ • Series.swift           │
        │ • AppConstants.swift     │
        │ • Logger.swift           │
        │ • SeriesManager.swift    │
        └──────────────────────────┘
                  ↑        ↑
         ┌────────┘        └────────┐
         │                          │
┌────────────────────┐    ┌────────────────────┐
│ Share Extension    │    │ Share Extension    │
│     (iOS)          │    │    (macOS)         │
├────────────────────┤    ├────────────────────┤
│ • ShareViewController  │    │ • ShareViewController  │
│ • import UIKit     │    │ • import AppKit    │
│ • UIViewController │    │ • NSViewController │
│ • UIAlertController│    │ • NSAlert          │
│                    │    │                    │
│ Target: iOS only   │    │ Target: macOS only │
└────────────────────┘    └────────────────────┘
```

## Rationale

**Why separate targets:**

- ✅ No `#if os()` conditionals in extension code
- ✅ Each extension uses native platform frameworks (UIKit vs AppKit)
- ✅ Standard Apple pattern (many multi-platform apps do this)
- ✅ Cleaner, more readable code
- ✅ Both can still share `ModelContainerFactory` and all models
- ✅ Easier to maintain and debug

**What stays unified:**

- Main app continues to support both platforms (existing conditionals are manageable)
- All data models remain shared (`ValueSnapshot`, `Series`)
- All utilities remain shared (`ModelContainerFactory`, `AppConstants`, `Logger`, `SeriesManager`)
- CloudKit configuration stays centralized in `ModelContainerFactory`

**Code duplication concerns:**

- Only UI layer differs between extensions (~150 lines each)
- Core logic (image processing, SwiftData operations) is identical
- Can extract common logic to shared helper functions if duplication becomes problematic
- Platform-specific UI code (alerts, view controllers) cannot be shared anyway

## Implementation Plan

### Step 1: Rename Current Extension to iOS-specific

**Directory rename:**

- From: `Summa Share Extension/`
- To: `Summa Share Extension iOS/`

**Target rename in Xcode:**

- From: `Summa Share Extension`
- To: `Summa Share Extension (iOS)`

**Files to rename:**

- `Summa Share Extension/ShareViewController.swift` → `Summa Share Extension iOS/ShareViewController.swift`
- `Summa Share Extension/Info.plist` → `Summa Share Extension iOS/Info.plist`
- `Summa Share Extension/Base.lproj/` → `Summa Share Extension iOS/Base.lproj/`
- `Summa Share ExtensionDebug.entitlements` → `Summa Share Extension iOSDebug.entitlements`

**Keep existing iOS code unchanged** - it already works perfectly.

### Step 2: Create macOS Extension Target

Create new app extension target in Xcode:

- **Name:** `Summa Share Extension (macOS)`
- **Type:** Share Extension
- **Platform:** macOS only
- **Framework:** AppKit
- **Bundle ID:** `com.grtnr.Summa.ShareExtension-macOS`

Xcode will create:

- `Summa Share Extension macOS/` directory
- Basic extension template files
- Target configuration in `project.pbxproj`

### Step 3: Implement macOS ShareViewController

Create: `Summa Share Extension macOS/ShareViewController.swift`

```swift
//
//  ShareViewController.swift
//  Summa Share Extension (macOS)
//

import AppKit
import UniformTypeIdentifiers
import SwiftData

class ShareViewController: NSViewController {

    // Access shared SwiftData container via App Group
    private var modelContainer: ModelContainer?
    private var containerError: Error?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize model container
        do {
            modelContainer = try ModelContainerFactory.createSharedContainer()
            processSharedImage()
        } catch {
            containerError = error
            showErrorAndDismiss(message: "Unable to access Summa database. Please ensure the app is properly installed.")
        }
    }

    private func processSharedImage() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            completeRequest(success: false)
            return
        }

        // Check if it's an image
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier) { [weak self] (item, error) in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    logError("Error loading image: \(error)")
                    #endif
                    DispatchQueue.main.async {
                        self.completeRequest(success: false)
                    }
                    return
                }

                // Get image data
                var imageData: Data?

                if let url = item as? URL {
                    imageData = try? Data(contentsOf: url)
                } else if let image = item as? NSImage,
                          let tiffData = image.tiffRepresentation,
                          let bitmap = NSBitmapImageRep(data: tiffData) {
                    imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
                } else if let data = item as? Data {
                    imageData = data
                }

                guard let imageData = imageData else {
                    DispatchQueue.main.async {
                        self.completeRequest(success: false)
                    }
                    return
                }

                // Create pending snapshot
                self.createPendingSnapshot(with: imageData)
            }
        } else {
            completeRequest(success: false)
        }
    }

    private func createPendingSnapshot(with imageData: Data) {
        // Ensure we have a valid model container
        guard let modelContainer = modelContainer else {
            #if DEBUG
            logError("ERROR: ModelContainer not available")
            #endif
            completeRequest(success: false)
            return
        }

        // Create new snapshot from screenshot - will trigger analysis in main app
        let snapshot = ValueSnapshot.fromScreenshot(imageData, date: Date())

        #if DEBUG
        log("Created snapshot with state: \(snapshot.analysisState)")
        log("Has image data: \(snapshot.sourceImage != nil)")
        #endif

        // Insert and save on background thread
        Task {
            do {
                let context = modelContainer.mainContext
                context.insert(snapshot)
                try context.save()

                #if DEBUG
                log("Snapshot saved to SwiftData")
                #endif

                await MainActor.run {
                    self.completeRequest(success: true)
                }
            } catch {
                #if DEBUG
                logError("Error saving snapshot: \(error)")
                #endif
                await MainActor.run {
                    self.completeRequest(success: false)
                }
            }
        }
    }

    private func completeRequest(success: Bool) {
        DispatchQueue.main.async {
            if success {
                // Show brief success message
                let alert = NSAlert()
                alert.messageText = "Saved to Summa"
                alert.informativeText = "Screenshot ready to process"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")

                // Show alert and complete
                alert.runModal()
                self.extensionContext?.completeRequest(returningItems: nil)
            } else {
                self.extensionContext?.cancelRequest(withError: NSError(domain: "SummaShare", code: -1))
            }
        }
    }

    private func showErrorAndDismiss(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = message
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")

            alert.runModal()
            self.extensionContext?.cancelRequest(withError: NSError(
                domain: "SummaShare",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        }
    }
}
```

**Key differences from iOS version:**

- `import AppKit` instead of `import UIKit`
- `NSViewController` instead of `UIViewController`
- `NSAlert` instead of `UIAlertController`
- `NSImage` instead of `UIImage` (with different data conversion)
- `alert.runModal()` instead of `present(alert, animated:)`

**Identical to iOS version:**

- Model container initialization via `ModelContainerFactory`
- Image processing logic structure
- SwiftData operations (insert, save)
- Error handling approach

### Step 4: Configure macOS Extension Info.plist

Create: `Summa Share Extension macOS/Info.plist`

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
    </dict>
</dict>
</plist>
```

**Note:** Identical structure to iOS version. Share extensions use the same Info.plist structure on both platforms.

### Step 5: Configure Entitlements

Both extensions need identical capabilities for App Group and CloudKit access:

#### iOS Extension

File: `Summa Share Extension iOSDebug.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.grtnr.Summa</string>
    </array>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.grtnr.Summa</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
</dict>
</plist>
```

#### macOS Extension

File: `Summa Share Extension macOSDebug.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Group for sharing SwiftData database -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.grtnr.Summa</string>
    </array>

    <!-- CloudKit for data sync -->
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.grtnr.Summa</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>

    <!-- macOS-specific: App Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- macOS-specific: Network access for CloudKit -->
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

**Key difference:** macOS extensions require App Sandbox and explicit network client entitlement.

### Step 6: Configure Shared File Membership

Ensure these files are added to **all three targets** in Xcode:

- ✅ Summa (main app)
- ✅ Summa Share Extension (iOS)
- ✅ Summa Share Extension (macOS)

**Files to share:**

- `Summa/Models/ValueSnapshot.swift`
- `Summa/Models/Series.swift`
- `Summa/Utils/ModelContainerFactory.swift`
- `Summa/Utils/AppConstants.swift`
- `Summa/Utils/Logger.swift`
- `Summa/Utils/SeriesManager.swift`

**How to configure in Xcode:**

1. Select file in Project Navigator
2. Open File Inspector (right panel)
3. Check boxes for all three targets under "Target Membership"

### Step 7: Update Xcode Project Configuration

Update `Summa.xcodeproj/project.pbxproj`:

**iOS Extension (existing):**

```
F97186E02ECC8CBA00AE1AD7 /* Summa Share Extension.appex */ = {
    platformFilter = ios;
};
```

**macOS Extension (add):**

```
[NEW_UUID] /* Summa Share Extension macOS.appex */ = {
    platformFilter = macos;
};
```

**Main App Build Phase (update):**

```
F97186E52ECC8CBA00AE1AD7 /* Embed Foundation Extensions */ = {
    files = (
        F97186E02ECC8CBA00AE1AD7 /* Summa Share Extension iOS.appex */,
        [NEW_UUID] /* Summa Share Extension macOS.appex */,
    );
};
```

## Testing Strategy

### Pre-Implementation Baseline

Document current behavior:

1. ✅ iOS: Share image → Summa works
2. ✅ iOS → macOS: Data syncs via CloudKit
3. ❌ macOS: No share extension available

### Post-Implementation Verification

#### Test 1: iOS Share Extension (No Regression)

1. iOS: Build and run on simulator
2. Take screenshot (Cmd+S in simulator)
3. Share screenshot → Summa
4. Verify: Success alert appears
5. Open main app → Verify entry appears
6. macOS: Open main app → Verify entry synced

**Expected:** iOS extension continues to work exactly as before.

#### Test 2: macOS Share Extension (New Feature)

1. macOS: Build and run
2. Find an image file in Finder
3. Right-click → Share → Summa
4. Verify: Success alert appears
5. macOS: Open main app → Verify entry appears
6. iOS: Open main app → Verify entry synced

**Expected:** macOS extension works identically to iOS extension.

#### Test 3: Bidirectional Sync

1. iOS: Share screenshot
2. Wait 5 seconds
3. macOS: Verify entry appears
4. macOS: Share image
5. Wait 5 seconds
6. iOS: Verify entry appears

**Expected:** Both extensions sync data properly via CloudKit.

#### Test 4: Concurrent Usage

1. iOS: Share 3 images rapidly
2. macOS: Share 2 images rapidly
3. Wait for sync
4. Both devices: Verify all 5 entries appear

**Expected:** No data loss, all entries sync correctly.

### Debugging

**Console filters:**

```bash
# CloudKit activity
process:Summa subsystem:com.apple.cloudkit

# SwiftData logs
process:Summa category:SwiftData

# Extension logs
process:com.grtnr.Summa.ShareExtension-iOS
process:com.grtnr.Summa.ShareExtension-macOS
```

**CloudKit Dashboard:**

1. Go to [developer.apple.com/icloud/dashboard](https://developer.apple.com/icloud/dashboard)
2. Select `iCloud.com.grtnr.Summa`
3. Check Private Database → `CD_ValueSnapshot` records
4. Verify records created from both iOS and macOS extensions

## Files to Create/Modify

### New Files

- `Summa Share Extension macOS/ShareViewController.swift` (NEW)
- `Summa Share Extension macOS/Info.plist` (NEW)
- `Summa Share Extension macOS/Base.lproj/` (NEW, if storyboard needed)
- `Summa Share Extension macOSDebug.entitlements` (NEW)

### Renamed Files

- `Summa Share Extension/` → `Summa Share Extension iOS/`
- `Summa Share ExtensionDebug.entitlements` → `Summa Share Extension iOSDebug.entitlements`

### Modified Files

- `Summa.xcodeproj/project.pbxproj` (add macOS target, rename iOS target, update embed phase)

### Shared Files (verify target membership only)

- `Summa/Models/ValueSnapshot.swift`
- `Summa/Models/Series.swift`
- `Summa/Utils/ModelContainerFactory.swift`
- `Summa/Utils/AppConstants.swift`
- `Summa/Utils/Logger.swift`
- `Summa/Utils/SeriesManager.swift`

## Benefits

1. **Platform-native code**: Each extension uses appropriate UI framework
2. **No conditionals**: Cleaner, more readable extension code
3. **Standard pattern**: Aligns with Apple's recommended multi-platform approach
4. **Maintainable**: Changes to one platform don't affect the other
5. **Reuses infrastructure**: Both extensions leverage existing `ModelContainerFactory`
6. **Complete feature parity**: macOS gains same share extension capabilities as iOS

## Risks & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Code duplication between extensions | High | Low | Core logic is identical. Only UI differs (~30 lines). Can extract common helpers if needed. |
| Forgetting to update both extensions | Medium | Medium | Document clearly. Consider shared helper functions. Test both platforms. |
| Different behavior on each platform | Low | High | Extensive cross-platform testing. Use same `ModelContainerFactory`. Verify CloudKit records from both sources. |
| macOS entitlements misconfiguration | Medium | High | Follow exact template above. Test CloudKit sync explicitly. Check console for errors. |

## Architecture Decision (by Till)

(To be filled in after review)
