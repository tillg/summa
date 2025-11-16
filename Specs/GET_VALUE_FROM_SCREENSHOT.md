# Spec: Extract Value from Screenshot

## Overview

Enable users to add value snapshots by importing screenshots (e.g., from banking apps) and automatically extracting the monetary value using on-device OCR.

## User Flow

1. User takes/imports a screenshot containing financial information
2. App creates a new ValueSnapshot with the image
3. App automatically processes the image to extract:
   - Primary monetary value
   - Date (if present)
   - Appropriate series assignment
4. User confirms/corrects extracted values
5. ValueSnapshot is saved with confirmed data

## Data Model Changes

### ValueSnapshot Extensions

Add the following fields to the `ValueSnapshot` model:

```swift
// Image storage
@Attribute(.externalStorage) var sourceImage: Data?  // Original screenshot

// Processing state
var imageProcessingState: ImageProcessingState = .none
var valuesConfirmed: Bool = true  // false when OCR-extracted, true after user confirmation

enum ImageProcessingState: String, Codable {
    case none        // No image attached
    case pending     // Image attached, awaiting processing
    case processing  // Currently being processed
    case processed   // Processing complete
    case failed      // Processing failed
}
```

### Processing Metadata

Consider storing OCR confidence and extraction metadata:

```swift
// OCR metadata (optional, for debugging/improvement)
var ocrConfidence: Double?  // 0.0 to 1.0
var extractedText: String?  // Full OCR text for reference
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

## Implementation Phases

### Phase 1: Basic OCR (MVP)
1. Add image field to ValueSnapshot model
2. Implement Vision framework OCR
3. Basic regex-based value extraction
4. Manual series selection
5. User confirmation UI

### Phase 2: Enhanced Recognition
1. Improved parsing with context clues
2. Date extraction from screenshots
3. Automatic series suggestion
4. Confidence indicators in UI

### Phase 3: Advanced Features (Future)
1. Foundation Models integration (iOS 18+)
2. Multi-value extraction (multiple accounts)
3. Receipt/invoice itemization
4. Historical pattern learning

## UI/UX Considerations

1. **Image Import**
   - Photo library picker
   - Drag & drop support (iPad)
   - Live camera capture (future)

2. **Confirmation Interface**
   - Show extracted values with edit capability
   - Highlight low-confidence extractions
   - Series picker with smart suggestion

3. **Error Handling**
   - Clear messaging for failed extractions
   - Allow manual entry as fallback
   - Retry processing option

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