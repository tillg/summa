# Spec: Extract Value from Screenshot

## Overview

Enable users to add value snapshots by importing screenshots (e.g., from banking apps), initially with manual value entry and later with automatic extraction using on-device OCR.

## Implementation Approach

This feature will be implemented in two distinct phases:

### Phase 1: Screenshot Storage with Manual Entry
Store screenshots alongside value snapshots for reference, with users manually entering the values. This provides immediate value by creating a visual record without the complexity of OCR.

### Phase 2: Automated Value Extraction
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

## Phase 2: Automated OCR Extraction (Future Enhancement)

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

### Phase 1 Deliverables (Immediate)

- Add screenshot attachment to ValueSnapshot model
- Update AddValueSnapshotView with image picker
- Store images with SwiftData external storage
- Display image indicators in value history
- View full screenshots from history list
- Manual value entry (no changes to current flow)

### Phase 2 Deliverables (Future)

- Integrate Vision framework for OCR
- Implement value extraction algorithms
- Add confirmation/correction UI
- Store OCR metadata and confidence scores
- Auto-populate value field from screenshots
- Smart series detection based on text

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
