# ImageAnalysisService Usage Guide

**Version:** 1.0
**Target Platforms:** iOS 26+, iPadOS 26+, macOS 26+
**Location:** `Summa/Services/ImageAnalysis/`

---

## Overview

The ImageAnalysisService provides on-device image analysis using Apple's Vision framework. It extracts text, detects faces, and classifies objects from images with confidence scores and priority ranking.

**Primary Use Case for Summa:** Automated text recognition and value extraction from e-banking screenshots to automatically populate ValueSnapshot entries.

### Key Features

- **Text Recognition** with confidence scores and priority ranking (1 = highest importance)
- **Face Detection** with landmarks and capture quality (optional, not needed for Summa)
- **Object Classification** with confidence scores (optional, not needed for Summa)
- **Cross-platform support** for iOS, iPadOS, and macOS
- **Reactive state management** using @Observable macro
- **Async/await API** for non-blocking processing

---

## Quick Start

### 1. Basic Usage

```swift
import SwiftUI

struct ScreenshotAnalyzerView: View {
    @State private var imageAnalysis = ImageAnalysisService()
    @State private var selectedImage: UIImage?

    var body: some View {
        VStack {
            if imageAnalysis.isAnalyzing {
                ProgressView("Analyzing screenshot...")
            } else if let error = imageAnalysis.error {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
            } else if let results = imageAnalysis.analyzedImage?.textResults {
                ResultsView(textResults: results)
            }

            Button("Select Screenshot") {
                // Show image picker
            }
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if let image = newValue {
                Task {
                    await imageAnalysis.analyze(image: image)
                }
            }
        }
    }
}
```

### 2. Extract Numeric Values from Screenshot

```swift
extension ImageAnalysisService {
    /// Extract numeric values from analyzed text results
    func extractNumericValues() -> [Double] {
        guard let results = analyzedImage?.textResults else { return [] }

        return results
            .filter { $0.confidence > 0.8 }  // High confidence only
            .filter { $0.priority <= 3 }     // Top 3 priority levels
            .compactMap { extractNumber(from: $0.text) }
    }

    private func extractNumber(from text: String) -> Double? {
        // Remove currency symbols, thousands separators, etc.
        let cleaned = text
            .replacingOccurrences(of: "[^0-9.-]", with: "", options: .regularExpression)
        return Double(cleaned)
    }
}
```

---

## E-Banking Screenshot Analysis

This is the primary integration point for Summa's automated value extraction feature.

### Background Processing Pattern

```swift
import Foundation

actor ScreenshotProcessor {
    private let imageAnalysis = ImageAnalysisService()

    /// Process an e-banking screenshot and extract the primary balance/value
    func processEBankingScreenshot(_ image: UIImage) async throws -> Double? {
        // Analyze the screenshot
        await imageAnalysis.analyze(image: image)

        guard let textResults = imageAnalysis.analyzedImage?.textResults else {
            throw ScreenshotProcessingError.analysisFailure
        }

        // Sort by priority (1 = highest importance)
        let prioritizedText = textResults.sorted { $0.priority < $1.priority }

        // Extract numeric values with high confidence
        let numericValues = prioritizedText
            .filter { $0.confidence > 0.8 }        // High confidence threshold
            .filter { $0.priority <= 3 }           // Top 3 priority levels
            .compactMap { extractMonetaryValue(from: $0.text) }

        // Return the most prominent value (usually account balance)
        return numericValues.first
    }

    /// Extract monetary value from text (handles currency symbols, thousands separators)
    private func extractMonetaryValue(from text: String) -> Double? {
        // Common patterns:
        // "$1,234.56"
        // "1'234.56 CHF"
        // "€ 1.234,56"
        // "1234.56"

        var cleaned = text

        // Remove currency symbols
        cleaned = cleaned.replacingOccurrences(of: "[$€£¥₹₽¢₣₤₧₨₩₪₫₱₡₨₭₮₴₵₸₹₺₼₽₾₿]", with: "", options: .regularExpression)

        // Remove common currency codes
        cleaned = cleaned.replacingOccurrences(of: "\\b(USD|EUR|GBP|CHF|JPY|CNY)\\b", with: "", options: .regularExpression)

        // Detect decimal separator (last . or ,)
        let lastDot = cleaned.lastIndex(of: ".")
        let lastComma = cleaned.lastIndex(of: ",")

        // Handle European format (1.234,56) vs US format (1,234.56)
        if let comma = lastComma, let dot = lastDot {
            if comma > dot {
                // European format: remove dots (thousands), replace comma with dot
                cleaned = cleaned.replacingOccurrences(of: ".", with: "")
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            } else {
                // US format: just remove commas
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        } else if lastComma != nil {
            // Only comma present - assume European decimal
            cleaned = cleaned.replacingOccurrences(of: "'", with: "")  // Swiss thousands separator
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        } else {
            // Only dots or no separators - remove non-numeric except last dot
            cleaned = cleaned.replacingOccurrences(of: "'", with: "")
        }

        // Keep only digits, dot, and negative sign
        cleaned = cleaned.replacingOccurrences(of: "[^0-9.-]", with: "", options: .regularExpression)

        return Double(cleaned)
    }
}

enum ScreenshotProcessingError: Error {
    case analysisFailure
    case noNumericValuesFound
}
```

### Integration with ValueSnapshot

```swift
import SwiftData

extension ContentView {
    /// Process a screenshot and create a new ValueSnapshot
    func processScreenshotAndCreateSnapshot(
        _ image: UIImage,
        series: Series,
        date: Date = Date(),
        notes: String = ""
    ) async {
        let processor = ScreenshotProcessor()

        do {
            guard let extractedValue = try await processor.processEBankingScreenshot(image) else {
                // Show error: no value found
                return
            }

            // Create new snapshot with extracted value
            let snapshot = ValueSnapshot(
                value: extractedValue,
                date: date,
                notes: notes.isEmpty ? "Auto-extracted from screenshot" : notes,
                series: series
            )

            modelContext.insert(snapshot)
            try modelContext.save()

            // Success feedback
            print("Created snapshot with value: \(extractedValue)")

        } catch {
            // Handle error
            print("Failed to process screenshot: \(error)")
        }
    }
}
```

---

## API Reference

### ImageAnalysisService

**Main service class for image analysis**

#### Properties

```swift
@Observable
public final class ImageAnalysisService {
    /// The current analyzed image with all results
    public private(set) var analyzedImage: AnalyzedImage?

    /// Indicates whether an analysis is currently in progress
    public private(set) var isAnalyzing: Bool

    /// The most recent error, if any
    public private(set) var error: Error?
}
```

#### Methods

```swift
/// Analyzes an image and updates the analyzedImage property
@MainActor
public func analyze(image: IAPlatformImage) async

/// Clears the current analysis results
public func clear()
```

### TextRecognitionResult

**Represents recognized text with metadata**

```swift
public struct TextRecognitionResult {
    /// The recognized text string
    let text: String

    /// Confidence score (0.0 to 1.0)
    let confidence: Float

    /// Priority ranking (1 = highest importance)
    let priority: Int

    /// Bounding box in normalized coordinates (0.0 to 1.0)
    let boundingBox: CGRect

    /// Estimated point size of the text
    let estimatedPointSize: CGFloat

    /// Height in pixels
    let heightInPixels: CGFloat
}
```

### AnalyzedImage

**Container for all analysis results**

```swift
public struct AnalyzedImage {
    /// The original image
    let originalImage: IAPlatformImage

    /// All recognized text results
    let textResults: [TextRecognitionResult]

    /// Detected faces (optional, not needed for Summa)
    let faceResults: [FaceRecognitionResult]

    /// Classified objects (optional, not needed for Summa)
    let objectResults: [ObjectRecognitionResult]

    /// Size of the analyzed image
    let imageSize: CGSize
}
```

### IAPlatformImage

**Cross-platform image type alias**

```swift
#if canImport(UIKit)
public typealias IAPlatformImage = UIImage
#else
public typealias IAPlatformImage = NSImage
#endif
```

---

## Text Priority System

The `IAFontSizeAnalyzer` assigns priority scores to help identify the most important text:

**Priority Scoring Factors:**
- **Font size** - Larger text gets higher priority (lower number)
- **Bounding box size** - Larger text blocks ranked higher
- **Position** - Text position can influence ranking

**Priority Levels:**
- `1` = Highest importance (large, prominent text like account balances)
- `2-3` = Medium importance (transaction amounts, labels)
- `4+` = Lower importance (small text, footnotes)

**For E-Banking Screenshots:**
- Account balances: Usually priority 1-2 (large, prominent)
- Transaction amounts: Priority 2-3 (medium-large)
- Labels/descriptions: Priority 3+ (smaller text)

### Example: Filtering by Priority

```swift
let highPriorityText = textResults
    .filter { $0.priority <= 2 }
    .sorted { $0.priority < $1.priority }

let topValue = highPriorityText.first { result in
    extractNumber(from: result.text) != nil
}
```

---

## Visualization Component

The service includes `IAImageOverlayView` for debugging and visualizing results:

```swift
import SwiftUI

struct AnalysisDebugView: View {
    let analyzedImage: AnalyzedImage

    var body: some View {
        IAImageOverlayView(analyzedImage: analyzedImage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

**Features:**
- Displays bounding boxes around detected text
- Color-coded by priority (red = high, yellow = medium, green = low)
- Shows confidence scores
- Interactive tap to see details

---

## Error Handling

```swift
// Check for errors after analysis
if let error = imageAnalysis.error {
    switch error {
    case let analysisError as ImageAnalysisError:
        // Handle specific analysis errors
        print("Analysis error: \(analysisError.localizedDescription)")

    default:
        // Handle other errors
        print("Unknown error: \(error)")
    }
}
```

**Common Errors:**
- `imageProcessingFailed` - Failed to convert or process image
- `visionRequestFailed` - Vision framework error
- `noImageData` - Could not load image data

---

## Performance Considerations

### Memory Usage
- Images are temporarily saved to disk during processing
- Cleanup is automatic after analysis completes
- For large images, consider downscaling before analysis

### Processing Time
- Text recognition: ~1-3 seconds on modern devices
- Face detection: ~0.5-1 second (if enabled)
- Object classification: ~1-2 seconds (if enabled)

### Best Practices
```swift
// Process screenshots in the background
Task.detached {
    await processor.processScreenshot(image)
}

// Batch processing
for image in screenshots {
    await imageAnalysis.analyze(image: image)
    await Task.sleep(nanoseconds: 100_000_000) // Small delay between analyses
}
```

---

## Framework Requirements

**Automatically linked frameworks:**
- `Vision` - Core image analysis
- `SwiftUI` - IAImageOverlayView component
- `CoreImage` - Image processing
- `ImageIO` - Image metadata
- `Observation` - @Observable macro (iOS 17+)

**No special entitlements required** - Vision framework is part of standard SDK.

---

## Platform-Specific Notes

### iOS/iPadOS
- Works with `UIImage` directly
- Supports device orientation metadata
- Full feature set available

### macOS
- Uses `NSImage` (transparently via `IAPlatformImage`)
- No orientation metadata (always assumes `.up`)
- All features work identically

### Universal Apps
The service handles platform differences internally - your code works the same on all platforms.

---

## Examples

### Example 1: Simple Text Extraction

```swift
let service = ImageAnalysisService()
await service.analyze(image: screenshot)

if let textResults = service.analyzedImage?.textResults {
    for result in textResults {
        print("\(result.text) (confidence: \(result.confidence))")
    }
}
```

### Example 2: Find Account Balance

```swift
func findAccountBalance(_ image: UIImage) async -> Double? {
    let service = ImageAnalysisService()
    await service.analyze(image: image)

    guard let results = service.analyzedImage?.textResults else { return nil }

    // Look for large, prominent numbers (likely the balance)
    let candidates = results
        .filter { $0.priority <= 2 }
        .filter { $0.confidence > 0.85 }
        .compactMap { result -> (Double, Int)? in
            guard let value = extractNumber(from: result.text) else { return nil }
            return (value, result.priority)
        }
        .sorted { $0.1 < $1.1 }  // Sort by priority

    return candidates.first?.0
}
```

### Example 3: Confidence Threshold Filtering

```swift
// Get only high-confidence text
let highConfidenceText = service.analyzedImage?.textResults
    .filter { $0.confidence >= 0.9 }
    ?? []

// Get text sorted by confidence
let sortedByConfidence = highConfidenceText
    .sorted { $0.confidence > $1.confidence }
```

---

## Troubleshooting

### No Text Detected
- **Check image quality:** Ensure text is clear and not blurry
- **Verify image orientation:** Wrong orientation can affect recognition
- **Check lighting:** Poor lighting reduces recognition accuracy
- **Text size:** Very small text (<10pt) may not be recognized

### Low Confidence Scores
- Image resolution too low
- Unusual fonts or handwriting
- Poor contrast between text and background
- Partial occlusion or text cutoff

### Incorrect Priority Ranking
- Very crowded layouts may affect priority calculation
- Unusual text layouts (vertical text, rotated text)
- Solution: Filter by both priority AND position if needed

### Performance Issues
- Downscale large images before processing
- Process one image at a time
- Use background tasks for batch processing

---

## Migration Notes

### From VNRecognizeTextRequest (Legacy)

If you have existing Vision code using `VNRecognizeTextRequest`:

**Old way:**
```swift
let request = VNRecognizeTextRequest()
let handler = VNImageRequestHandler(cgImage: cgImage)
try handler.perform([request])
```

**New way (this service):**
```swift
let service = ImageAnalysisService()
await service.analyze(image: uiImage)
```

The service handles all Vision requests internally and provides a cleaner, async API.

---

## Future Enhancements

Potential additions for Summa-specific needs:

1. **Custom OCR training** - Train for specific bank formats
2. **Multi-language support** - Detect and handle different languages
3. **Receipt parsing** - Extract line items from receipts
4. **Table detection** - Extract structured data from tables
5. **Barcode scanning** - QR codes for payment references

---

## Support and Issues

For issues or questions:
1. Check this documentation
2. Review Apple Vision framework documentation
3. Check image quality and format
4. Enable debug overlay to visualize detection

---

**Last Updated:** November 2025
**Compatible with:** iOS 26.0+, iPadOS 26.0+, macOS 26.0+
