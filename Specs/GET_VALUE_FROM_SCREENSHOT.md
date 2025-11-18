# Spec: Extract Value from Screenshot

## Overview

Enable users to add value snapshots by importing screenshots (e.g., from banking apps), initially with manual value entry and later with automatic extraction using on-device OCR.

## Implementation Approach

This feature will be implemented in two distinct phases:

### Phase 1: Screenshot Storage with Manual Entry
Store screenshots alongside value snapshots for reference, with users manually entering the values. This provides immediate value by creating a visual record without the complexity of OCR.

### Phase 2: Share Sheet Integration for Quick Capture
Enable users to share screenshots directly to Summa from any app (Photos, banking apps, etc.) to create placeholder ValueSnapshots that can be processed later. This provides a quick capture workflow without interrupting the user's current task.

### Phase 3: Automated Value Extraction
Add OCR capabilities to automatically extract monetary values from stored screenshots, reducing manual data entry.

## Phase 1: Screenshot Storage (Immediate Implementation)

### User Flow

1. User opens Add Value form
2. User can optionally attach a screenshot via:
   - Photo library picker
   - Camera capture (if available)
3. User manually enters the value and other details as normal
4. Screenshot is stored with the ValueSnapshot for reference
5. User can view stored screenshots when reviewing value history

### Data Model Changes

Add to `ValueSnapshot` model:

```swift
// Image storage
@Attribute(.externalStorage) var sourceImage: Data?  // Original screenshot
var imageAttachedDate: Date?  // When image was added
```

### UI Changes

#### AddValueSnapshotView
- Add "Attach Screenshot" button below the value input field
- Show thumbnail preview of attached image
- Allow removing attached image before saving
- Camera/Photo Library picker options

#### ContentView / Value History List
- Show image indicator icon for snapshots with attached screenshots
- Tap to view full-size screenshot in modal/sheet

### Technical Implementation

```swift
import SwiftUI
import PhotosUI

// Image handling in AddValueSnapshotView
@State private var selectedImage: UIImage?
@State private var showingImagePicker = false
@State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary

// Convert UIImage to Data for storage
if let image = selectedImage,
   let imageData = image.jpegData(compressionQuality: 0.8) {
    newSnapshot.sourceImage = imageData
    newSnapshot.imageAttachedDate = Date()
}

// Display thumbnail in form
if let imageData = newSnapshot.sourceImage,
   let uiImage = UIImage(data: imageData) {
    Image(uiImage: uiImage)
        .resizable()
        .scaledToFit()
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 8))
}
```

### Implementation Checklist for Phase 1

- [ ] Update ValueSnapshot model with image fields
- [ ] Add PhotosUI import and permissions
- [ ] Create ImagePicker component (UIViewControllerRepresentable)
- [ ] Add "Attach Screenshot" button to AddValueSnapshotView
- [ ] Implement image preview in form
- [ ] Add image indicator to value history list items
- [ ] Create full-screen image viewer for history items
- [ ] Test with various image sizes and formats
- [ ] Verify CloudKit sync works with attached images

### Benefits of Phase 1
- Immediate visual record keeping
- Proof/reference for entered values
- No complex OCR implementation needed
- Foundation for Phase 2
- Users can start building a library of screenshots

## Phase 2: Share Sheet Integration (Next Implementation)

### Overview

Enable users to share images directly to Summa from other apps via iOS Share Sheet. When a user shares an image to Summa, the app creates a "pending" ValueSnapshot with the image attached but no value entered yet. The user can then review and complete these pending snapshots later in a dedicated workflow.

### User Flow

#### Quick Capture Flow
1. User views a screenshot in Photos app or takes screenshot in banking app
2. User taps Share button and selects "Summa" from Share Sheet
3. Summa receives the image and creates a pending ValueSnapshot in the background
4. User sees brief confirmation (optional: toast/notification)
5. User can continue with current task - no interruption

#### Review & Complete Flow
1. User opens Summa app
2. The Snapshots with just a picture are listed in the same list as the others but have a gray background and a small question mark symbol that indicates they are "pending" as state.
3. User taps a pending snapshot to complete it:
   - View full-size image
   - Select series
   - Enter value (manually or via OCR in Phase 3)
   - Edit date if needed
   - Add notes
   - Save or delete

### Data Model Changes

Extend the `ValueSnapshot` model to support pending state:

```swift
// Add to existing ValueSnapshot model

// Processing state for share sheet workflow
var processingState: ProcessingState = .completed

enum ProcessingState: String, Codable {
    case pending     // Image received via share sheet, needs user input
    case completed   // Fully populated snapshot (normal state)
}

// Make value optional to support pending state
// Change from: var value: Decimal
var value: Decimal?  // nil when in pending state

// CloudKit compatibility: already optional in current implementation
```

**Migration Notes:**
- Existing snapshots will have `processingState = .completed` by default
- Existing snapshots will have non-nil values (already entered)
- No data migration needed for Phase 1 → Phase 2

### Technical Implementation

#### 1. Share Extension Target

Create an iOS Share Extension to receive shared images:

**Setup Steps:**
1. Add new target in Xcode: File > New > Target > Share Extension
2. Name: "Summa Share Extension"
3. Enable App Groups for data sharing between main app and extension
4. Configure Info.plist to accept images only

**App Groups Configuration:**
```xml
<!-- Add to main app and share extension -->
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourcompany.summa</string>
</array>
```

**ShareViewController.swift:**
```swift
import UIKit
import Social
import UniformTypeIdentifiers
import SwiftData

class ShareViewController: UIViewController {

    // Access shared SwiftData container via App Group
    lazy var modelContainer: ModelContainer = {
        let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.yourcompany.summa")!
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
                    print("Error loading image: \(error)")
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
            value: nil,  // No value yet
            date: Date(),
            notes: nil,
            series: nil
        )
        snapshot.sourceImage = imageData
        snapshot.imageAttachedDate = Date()
        snapshot.processingState = .pending

        context.insert(snapshot)

        do {
            try context.save()
            completeRequest(success: true)
        } catch {
            print("Error saving snapshot: \(error)")
            completeRequest(success: false)
        }
    }

    private func completeRequest(success: Bool) {
        if success {
            // Optional: Show brief success message
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

**Info.plist Configuration for Share Extension:**
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
    <string>ShareViewController</string>
</dict>
```

#### 2. Modified Snapshots View

The SnapshotEditView and the Row in the list of ValueSnaphots need to be adapted to reflect the processingState.
The list Entry View should be extracted in their own file and be renamed to SnapshotListEntryView.

#### 3. Main App Integration

Update `ContentView` to show pending snapshots indicator:

```swift
// Add to ContentView
@Query(filter: #Predicate<ValueSnapshot> { $0.processingState == .pending })
private var pendingSnapshots: [ValueSnapshot]

@State private var showingPendingSnapshots = false

// Add to toolbar
.toolbar {
    ToolbarItem(placement: .navigationBarLeading) {
        Button {
            showingPendingSnapshots = true
        } label: {
            Label("Pending", systemImage: "tray")
                .badge(pendingSnapshots.count)
        }
        .disabled(pendingSnapshots.isEmpty)
    }
}
.sheet(isPresented: $showingPendingSnapshots) {
    PendingSnapshotsView()
}
```

### Implementation Checklist for Phase 2

- [ ] Enable App Groups in Xcode for main app
- [ ] Create Share Extension target
- [ ] Enable App Groups in Share Extension
- [ ] Configure SwiftData to use shared container (App Group)
- [ ] Add `processingState` field to ValueSnapshot model
- [ ] Make `value` field optional in ValueSnapshot
- [ ] Implement ShareViewController to handle shared images
- [ ] Configure Share Extension Info.plist (accept images only)
- [ ] Create PendingSnapshotsView
- [ ] Create PendingSnapshotRow component
- [ ] Create CompletePendingSnapshotView
- [ ] Add pending snapshots indicator to ContentView
- [ ] Test sharing from Photos app
- [ ] Test sharing from other apps (Safari, banking apps)
- [ ] Verify CloudKit sync works with pending snapshots
- [ ] Test completing pending snapshots
- [ ] Test deleting pending snapshots

### Benefits of Phase 2

- **Frictionless capture**: Add screenshots instantly without interrupting workflow
- **Batch processing**: Collect multiple screenshots and process them later when convenient
- **System integration**: Works with iOS Share Sheet from any app
- **Offline-first**: Screenshots saved locally, processed at user's convenience
- **Foundation for Phase 3**: Pending snapshots provide perfect entry point for automatic OCR processing

### Design Considerations

#### Badge Visibility
Show pending snapshot count in multiple places:
- Tab bar badge (if using tab navigation)
- Toolbar button badge
- Home screen app badge (optional, via notifications)

#### Background Processing
- Share extension runs in limited memory/time
- Keep processing minimal: just save image and basic metadata
- Heavy lifting (OCR, parsing) happens in main app

#### Error Handling
- Handle missing App Group configuration gracefully
- Provide clear error messages if share fails
- Allow retry mechanism in extension

#### User Experience
- Optional: Show quick toast notification after share
- Clear visual distinction between pending and completed snapshots
- Easy batch operations (complete all, delete all)

### Connection to Phase 3

Phase 2 creates the perfect foundation for Phase 3 (OCR):
- **Pending snapshots** become the queue for automatic processing
- When OCR is implemented, the flow becomes:
  1. User shares screenshot → pending snapshot created
  2. Main app automatically processes pending snapshots with OCR
  3. User reviews pre-filled values and confirms/corrects
  4. Snapshot marked as completed

This means Phase 2's UI and data model will require minimal changes when OCR is added in Phase 3.

## Phase 3: Automated OCR Extraction (Future Enhancement)

### User Flow

1. User takes/imports a screenshot containing financial information
2. App creates a new ValueSnapshot with the image
3. App automatically processes the image to extract:
   - Primary monetary value
   - Date (if present)
   - Appropriate series assignment
4. User confirms/corrects extracted values
5. ValueSnapshot is saved with confirmed data

### Data Model Changes

Extend the `ValueSnapshot` model with OCR-related fields:

```swift
// Phase 1 fields (already added)
@Attribute(.externalStorage) var sourceImage: Data?
var imageAttachedDate: Date?

// Phase 2: Additional OCR fields
var imageProcessingState: ImageProcessingState = .none
var valuesConfirmed: Bool = true  // false when OCR-extracted, true after user confirmation
var ocrConfidence: Double?  // 0.0 to 1.0
var extractedText: String?  // Full OCR text for reference

enum ImageProcessingState: String, Codable {
    case none        // No image attached
    case pending     // Image attached, awaiting processing
    case processing  // Currently being processed
    case processed   // Processing complete
    case failed      // Processing failed
}
```

## Technical Implementation

### Vision Framework for OCR (iOS 13.0+)

Apple's Vision framework provides robust on-device text recognition that runs entirely locally:

#### Core Components

**VNRecognizeTextRequest**: The primary API for text recognition
- Available since iOS 13.0
- Processes images on-device using Core ML
- No network connection required
- Utilizes device's Neural Engine for performance

#### Recognition Modes

1. **Accurate Mode** (`.accurate`)
   - Uses deep neural network model
   - Better for financial documents
   - Higher quality results
   - Slightly slower processing

2. **Fast Mode** (`.fast`)
   - Lightweight model
   - Quick processing
   - Suitable for real-time scenarios
   - May miss complex layouts

#### Implementation Example

```swift
import Vision
import UIKit

class ScreenshotProcessor {

    func extractValue(from image: UIImage) async throws -> ExtractedData {
        guard let cgImage = image.cgImage else {
            throw ProcessingError.invalidImage
        }

        // Create request handler
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // Configure text recognition request
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate  // Use accurate for financial data
        textRequest.usesLanguageCorrection = true // Fix common OCR errors
        textRequest.recognitionLanguages = ["en"] // Specify languages

        // Perform OCR
        try requestHandler.perform([textRequest])

        // Process results
        guard let observations = textRequest.results as? [VNRecognizedTextObservation] else {
            throw ProcessingError.noTextFound
        }

        // Extract text with confidence scores
        let recognizedText = observations.compactMap { observation in
            observation.topCandidates(1).first
        }

        // Parse for monetary values
        return parseFinancialData(from: recognizedText)
    }

    private func parseFinancialData(from candidates: [VNRecognizedText]) -> ExtractedData {
        // Implementation for extracting monetary values, dates, etc.
        // Use regex patterns for currency formats
        // Consider using NSDataDetector for structured data
    }
}
```

#### Key Features

- **Language Support**: Automatic language detection or specify languages
- **Language Correction**: NLP post-processing to fix OCR errors (e.g., "O" vs "0")
- **Confidence Scores**: Each recognized text has a confidence value
- **Bounding Boxes**: Get location of text for UI overlays

### Parsing Financial Data

#### Strategies for Value Extraction

1. **Regular Expressions**
   ```swift
   // Match currency patterns
   let currencyPattern = #"[\$€£¥]?\s*[\d,]+\.?\d*"#
   let regex = try NSRegularExpression(pattern: currencyPattern)
   ```

2. **NSDataDetector** (for structured data)
   ```swift
   let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
   // Can detect dates, addresses, links, etc.
   ```

3. **Context Clues**
   - Look for keywords: "Total", "Balance", "Amount"
   - Identify largest value as likely main amount
   - Use font size/position if available from Vision

### Series Assignment Logic

Implement smart series detection based on:

1. **Text Analysis**
   - Bank names or account identifiers
   - Account types (Checking, Savings, Investment)
   - Currency symbols

2. **Historical Patterns**
   - Previous screenshots from same source
   - User's typical series usage

3. **Fallback**
   - Assign to last-used series
   - Default to "Default" series if uncertain

## Advanced Features (Optional)

### Foundation Models Framework (iOS 18+, requires Apple Intelligence)

For more sophisticated text understanding, the Foundation Models framework provides on-device LLM capabilities:

**Requirements:**
- iOS 18.0+
- Apple Intelligence enabled
- Compatible device (iPhone 15 Pro or newer)

**Use Cases:**
- Complex document understanding
- Multi-value extraction
- Contextual series assignment

**Note**: This is optional and should gracefully degrade on older devices or when Apple Intelligence is unavailable.

```swift
import FoundationModels

// Check availability first
guard SystemLanguageModel.default.isAvailable else {
    // Fall back to basic OCR parsing
    return
}

// Create session for text analysis
let session = LanguageModelSession(model: .default)
let prompt = """
Extract the main monetary value from this text:
\(ocrText)
Return only the numeric value.
"""

let response = try await session.respond(to: prompt)
```

### UI Changes for Phase 2

1. **OCR Processing Flow**
   - Show processing indicator while analyzing image
   - Display extracted value with confidence indicator
   - Allow manual correction of extracted value
   - Highlight extracted text regions on image preview

2. **Confirmation Interface**
   - Pre-fill value field with extracted amount
   - Show confidence score (e.g., "95% confident")
   - Mark as "needs confirmation" if confidence < 90%
   - Allow toggling between OCR and manual entry modes

## Implementation Timeline

### Phase 1 Deliverables (Completed ✓)

- Add screenshot attachment to ValueSnapshot model
- Update AddValueSnapshotView with image picker
- Store images with SwiftData external storage
- Display image indicators in value history
- View full screenshots from history list
- Manual value entry (no changes to current flow)

### Phase 2 Deliverables (Next)

- Configure App Groups for data sharing
- Create Share Extension target
- Implement ShareViewController for receiving shared images
- Add `processingState` field to ValueSnapshot model
- Make `value` field optional
- Create PendingSnapshotsView UI
- Create CompletePendingSnapshotView UI
- Add pending snapshots indicator to main app
- Test share sheet integration across apps

### Phase 3 Deliverables (Future)

- Integrate Vision framework for OCR
- Implement value extraction algorithms
- Add automatic processing for pending snapshots
- Add confirmation/correction UI for OCR results
- Store OCR metadata and confidence scores
- Auto-populate value field from screenshots
- Smart series detection based on text
- Optional: Advanced parsing with Foundation Models (iOS 18+)

## Additional Considerations

## Privacy & Security

- All processing happens on-device
- No image data leaves the device
- Images stored in app's private container
- Consider automatic image deletion after processing

## Testing Considerations

1. **Test Cases**
   - Various banking app formats
   - Different currencies
   - Multiple languages
   - Poor quality images
   - Non-financial screenshots

2. **Performance**
   - Processing time targets
   - Memory usage with large images
   - Battery impact considerations

## References

- [Apple Vision Documentation - Text Recognition](https://developer.apple.com/documentation/vision/recognizing-text-in-images)
- [VNRecognizeTextRequest API](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
- [Foundation Models Framework](https://developer.apple.com/documentation/foundationmodels) (iOS 18+, optional)
