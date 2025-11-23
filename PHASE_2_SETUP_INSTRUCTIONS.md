# Phase 2 Setup Instructions

## Overview

Phase 2 implementation is partially complete. The core app has been updated to handle pending snapshots with the following changes:

### Completed ✓

1. **ValueSnapshot Model** - Updated with:
   - `processingState` field (stored as String, accessed via computed `state` property)
   - Optional `value` field to support pending state
   - New `ProcessingState` enum (.pending, .completed)

2. **UI Components** - Updated to handle pending snapshots:
   - `SnapshotListEntryView` - New component with gray background and question mark indicator for pending snapshots
   - `ContentView` - Now uses `SnapshotListEntryView`
   - `ValueSnapshotEditView` - Handles optional values and marks pending snapshots as completed when saved
   - `ValueSnapshotChart` - Filters out pending snapshots from chart display
   - `SeriesRowView` - Handles optional values

3. **Build Status** - Project builds successfully

### Remaining Steps (Require Xcode UI)

The following steps require manual configuration in Xcode to complete Phase 2:

---

## Step 1: Configure App Groups

App Groups allow the main app and Share Extension to share the same SwiftData database.

### Instructions:

1. Open `Summa.xcodeproj` in Xcode
2. Select the **Summa** project in the navigator
3. Select the **Summa** target
4. Go to **Signing & Capabilities** tab
5. Click **+ Capability** and add **App Groups**
6. Click the **+** button under App Groups
7. Enter: `group.com.tillgartner.summa` (or use your bundle identifier pattern)
8. Enable the checkbox next to the newly created App Group

**Important**: Remember the exact App Group identifier - you'll need it in later steps.

---

## Step 2: Create Share Extension Target

### Instructions:

1. In Xcode, go to **File > New > Target**
2. Select **iOS > Application Extension > Share Extension**
3. Click **Next**
4. Configure the target:
   - **Product Name**: `Summa Share Extension`
   - **Team**: (Your development team)
   - **Language**: Swift
   - **Organization Identifier**: (Same as main app)
5. Click **Finish**
6. When prompted "Activate 'Summa Share Extension' scheme?", click **Activate**

### Expected Result:
- New folder: `Summa Share Extension` in project navigator
- New files: `ShareViewController.swift` and `Info.plist`

---

## Step 3: Configure Share Extension Capabilities

### Instructions:

1. Select the **Summa Share Extension** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability** and add **App Groups**
4. Enable the **same App Group** you created in Step 1
   - ✓ `group.com.tillgartner.summa`

---

## Step 4: Update Share Extension Code

### Replace `ShareViewController.swift`:

Delete the default content and replace with:

```swift
//
//  ShareViewController.swift
//  Summa Share Extension
//

import UIKit
import Social
import UniformTypeIdentifiers
import SwiftData

class ShareViewController: UIViewController {

    // IMPORTANT: Replace with your App Group identifier from Step 1
    private let appGroupIdentifier = "group.com.tillgartner.summa"

    // Access shared SwiftData container via App Group
    lazy var modelContainer: ModelContainer = {
        let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
            .appending(path: "Summa.sqlite")

        let config = ModelConfiguration(url: storeURL)
        return try! ModelContainer(
            for: ValueSnapshot.self, Series.self,
            configurations: config
        )
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        processSharedImage()
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
                    print("Error loading image: \\(error)")
                    self.completeRequest(success: false)
                    return
                }

                // Get image data
                var imageData: Data?

                if let url = item as? URL {
                    imageData = try? Data(contentsOf: url)
                } else if let image = item as? UIImage {
                    imageData = image.jpegData(compressionQuality: 0.8)
                } else if let data = item as? Data {
                    imageData = data
                }

                guard let imageData = imageData else {
                    self.completeRequest(success: false)
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
        let context = modelContainer.mainContext

        // Create new pending snapshot
        let snapshot = ValueSnapshot(
            on: Date(),
            value: nil,  // No value yet - pending state
            series: nil,
            processingState: .pending
        )
        snapshot.sourceImage = imageData
        snapshot.imageAttachedDate = Date()

        context.insert(snapshot)

        do {
            try context.save()
            completeRequest(success: true)
        } catch {
            print("Error saving snapshot: \\(error)")
            completeRequest(success: false)
        }
    }

    private func completeRequest(success: Bool) {
        if success {
            // Show brief success message
            let alert = UIAlertController(
                title: "Saved to Summa",
                message: "Screenshot ready to process",
                preferredStyle: .alert
            )
            present(alert, animated: true) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.extensionContext?.completeRequest(returningItems: nil)
                }
            }
        } else {
            extensionContext?.cancelRequest(withError: NSError(domain: "SummaShare", code: -1))
        }
    }
}
```

**IMPORTANT**: Update the `appGroupIdentifier` constant to match your App Group from Step 1!

---

## Step 5: Configure Share Extension Info.plist

### Instructions:

1. Open `Summa Share Extension/Info.plist`
2. Find `NSExtension` dictionary
3. Update `NSExtensionAttributes` to accept only images:

```xml
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
```

---

## Step 6: Update Main App SwiftData Configuration

Update `SummaApp.swift` to use the App Group container:

### Instructions:

1. Open `Summa/SummaApp.swift`
2. Find the `modelContainer` initialization
3. Update it to use the App Group:

```swift
import SwiftUI
import SwiftData

@main
struct SummaApp: App {

    // IMPORTANT: Replace with your App Group identifier
    private let appGroupIdentifier = "group.com.grtnr.Summa"

    var sharedModelContainer: ModelContainer = {
        // Get App Group container URL
        guard let appGroupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.tillgartner.summa") else {
            fatalError("Failed to get App Group container")
        }

        let storeURL = appGroupURL.appending(path: "Summa.sqlite")
        let config = ModelConfiguration(url: storeURL)

        do {
            return try ModelContainer(
                for: ValueSnapshot.self, Series.self,
                configurations: config
            )
        } catch {
            fatalError("Could not create ModelContainer: \\(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
```

**IMPORTANT**: Update both instances of `appGroupIdentifier` to match your App Group!

---

## Step 7: Build and Test

### Build Steps:

1. Select **Summa** scheme
2. Build the project (⌘B)
3. Verify no errors

### Testing Steps:

1. Run the main **Summa** app on your device/simulator
2. Add a test value snapshot to verify the app works
3. Open **Photos** app
4. Select any image
5. Tap the **Share** button
6. Look for **Summa** in the share sheet
7. Tap **Summa** - you should see "Saved to Summa" alert
8. Open **Summa** app
9. You should see the pending snapshot with:
   - Gray background
   - Question mark icon
   - "Pending" label
10. Tap the pending snapshot
11. Fill in the value and series
12. Tap Save
13. Snapshot should now appear as normal (no gray background)

---

## Troubleshooting

### Issue: Share Extension doesn't appear in Share Sheet

**Solution**:
- Make sure both targets have the same App Group enabled
- Clean build folder (Shift+⌘K)
- Delete app from device/simulator and reinstall

### Issue: "Failed to get App Group container" crash

**Solution**:
- Verify App Group identifier is exactly the same in all three places:
  1. Main app capabilities
  2. Share Extension capabilities
  3. Code (both ShareViewController and SummaApp)

### Issue: Pending snapshots don't appear in main app

**Solution**:
- Verify both apps are using the same SwiftData store URL
- Check that the App Group identifier is correct
- Try force-quitting both apps and relaunching

### Issue: Build errors about missing types

**Solution**:
- Make sure the Share Extension target has access to:
  - `ValueSnapshot.swift`
  - `Series.swift`
  - `ProcessingState` enum
- You may need to add these files to the Share Extension target:
  1. Select the file in Project Navigator
  2. Open File Inspector (⌥⌘1)
  3. Check **Summa Share Extension** under Target Membership

---

## Phase 2 Complete! 🎉

Once testing is successful, Phase 2 is complete. Users can now:

1. Share screenshots from any app to Summa
2. Screenshots are saved as pending snapshots
3. Pending snapshots appear with gray background and question mark
4. Users can tap to complete them later
5. Once completed, they appear as normal value snapshots

### Next: Phase 3 (OCR) - Future Enhancement

Phase 3 will add automatic value extraction using Vision framework, but that's for later!
