# Copy ImageAnalysisService from Foundation-Models-Framework-Example to Summa

## Overview

This document outlines the plan to copy the ImageAnalysisService from Foundation-Models-Framework-Example to Summa. The service will be used to analyze screenshots of e-banking applications to automatically identify and extract values, running as a background service to process screenshots and update associated values.

**Target Platforms:** iOS 26+, iPadOS 26+, macOS 26+ (universal app with iPhone and iPad layouts)

**Primary Use Case:** Automated text recognition and value extraction from e-banking screenshots, with prioritization of recognized text elements to identify the most relevant values.

**Feature Scope:** Text recognition with confidence scores and priority ranking (face detection and object classification components will be included but are optional for Summa's use case).

---

## Execution Plan

### Phase 1: Copy Files

Copy the entire ImageAnalysis service module from Foundation-Models-Framework-Example to Summa.

**Source location:**
```
Foundation-Models-Framework-Example/Foundation Lab/Services/ImageAnalysis/
```

**Target location:**
```
Summa/Summa/Summa/Services/ImageAnalysis/
```

**Files to copy (10 files total):**

1. `ImageAnalysisService.swift` - Main @Observable service class
2. `Models/AnalyzedImage.swift` - Results container
3. `Models/TextRecognitionResult.swift` - Text analysis results with confidence and priority
4. `Models/FaceRecognitionResult.swift` - Face detection results (optional feature)
5. `Models/ObjectRecognitionResult.swift` - Object classification results (optional feature)
6. `Models/IAPlatformImage.swift` - Cross-platform image type (UIImage/NSImage/CGImage)
7. `Internal/IAVisionAnalyzer.swift` - Vision framework wrapper
8. `Internal/IAFontSizeAnalyzer.swift` - Text priority/importance calculation (critical for Summa's use case)
9. `Internal/IAImagePreprocessor.swift` - Image preparation utilities
10. `Views/IAImageOverlayView.swift` - SwiftUI visualization component

**Naming Convention:** All internal types retain the "IA" prefix (ImageAnalysis) to avoid naming conflicts with existing Summa code.

### Phase 2: Add Files to Xcode Project

**Manual step required in Xcode:**

1. Open `Summa.xcodeproj` in Xcode
2. Right-click on the `Summa` group in Project Navigator
3. Select "Add Files to Summa..."
4. Navigate to the copied `Services/ImageAnalysis/` folder
5. **Important settings:**
   - ✅ Check "Copy items if needed"
   - ✅ Select "Create groups" (not folder references)
   - ✅ Add to target: **Summa** (not Share Extension)
6. Click "Add"

**Result:** All 10 files will be added with proper group hierarchy:
- Services/ImageAnalysis/
  - ImageAnalysisService.swift
  - Models/ (4 files)
  - Internal/ (3 files)
  - Views/ (1 file)

### Phase 3: Verify Framework Dependencies

The ImageAnalysisService requires these frameworks (should auto-link):

- **Vision.framework** - Core image analysis (text recognition, face detection, object classification)
- **SwiftUI** - For IAImageOverlayView component
- **CoreImage** - Image processing utilities
- **ImageIO** - Image metadata and orientation handling
- **Observation** - @Observable macro support (iOS 17+)

**Verification:** Build the project after adding files. If you see "Cannot find type in scope" errors, verify the frameworks are linked in:
- Project Settings → Summa Target → Build Phases → Link Binary With Libraries

### Phase 4: Deployment Target Compatibility

✅ **No changes needed** - Summa targets iOS 26+, iPadOS 26+, and macOS 26+, which exceeds the service's minimum requirements (iOS 17.0+ / macOS 14.0+ for @Observable).

The service is fully compatible with Summa's deployment targets and includes:
- Cross-platform support for iOS, iPadOS, and macOS
- Conditional compilation for platform-specific image handling
- Adaptive layouts will work with existing iPhone/iPad screen size adaptations

### Phase 5: Create Usage Documentation

Create `Summa/Summa/ImageAnalysisService-Usage.md` with:

- **Quick Start Guide** - Basic integration steps
- **E-Banking Screenshot Analysis** - Specific guide for Summa's use case
- **Background Processing Pattern** - How to process screenshots asynchronously
- **Value Extraction Examples** - Using text priority to identify numeric values
- **API Reference** - Main types and methods
- **Error Handling** - Common issues and solutions

---

## Entitlements and Permissions

✅ **No special entitlements required** - The Vision framework is part of the standard iOS/macOS SDK.

**Info.plist keys** (if not already present):

- `NSPhotoLibraryUsageDescription` - Required if selecting images from photo library (likely already exists in Summa based on ImagePicker.swift)
- `NSCameraUsageDescription` - Only needed if capturing from camera

**No capability toggles needed** in Xcode project settings.

---

## Technical Details

### Service Architecture

The ImageAnalysisService uses modern Swift patterns:

- **@Observable macro** (iOS 17+) for reactive state management
- **async/await** for non-blocking analysis
- **@MainActor** isolation for UI updates
- **Value types** for thread-safe results

### Dependencies Between Files

```
ImageAnalysisService.swift (main class)
├── Uses: IAVisionAnalyzer (internal)
├── Uses: IAFontSizeAnalyzer (internal) ← Critical for Summa's value prioritization
├── Uses: IAImagePreprocessor (internal)
└── Returns: AnalyzedImage (public)
    ├── Contains: TextRecognitionResult (public) ← Primary data for Summa
    ├── Contains: FaceRecognitionResult (public)
    ├── Contains: ObjectRecognitionResult (public)
    └── Uses: IAPlatformImage (public)

IAImageOverlayView.swift (view)
└── Displays: AnalyzedImage (public)
```

### Cross-Platform Support

The service handles iOS/macOS differences internally:

- **Image types:** UIImage (iOS/iPadOS) vs NSImage (macOS) → unified via `IAPlatformImage` typealias
- **JPEG conversion:** Different APIs for each platform (handled transparently)
- **Image orientation:** UIImage has orientation metadata, NSImage doesn't (service normalizes)
- **All platform-specific code** is isolated in extensions with `#if canImport(UIKit)` / `#if canImport(AppKit)`

Summa's existing macOS image handling should work seamlessly with the service.

### What Summa Gets

After integration, Summa can:

1. **Create service instance:** `@State private var service = ImageAnalysisService()`
2. **Analyze screenshots:** `await service.analyze(image: ebankingScreenshot)`
3. **Access text results with priority:** `service.analyzedImage?.textResults.sorted { $0.priority < $1.priority }`
4. **Extract values:** Filter results by confidence, priority, or text patterns (e.g., numeric values)
5. **Display overlays:** `IAImageOverlayView(analyzedImage: analyzedImage)` for debugging
6. **Monitor progress:** `service.isAnalyzing` for UI feedback
7. **Handle errors:** `service.error` for error reporting

### Text Priority System

The `IAFontSizeAnalyzer` assigns priority scores (1 = highest importance) based on:

- **Font size** (relative to image dimensions)
- **Bounding box size** (larger text blocks get higher priority)
- **Position** (text at top of image may be weighted higher)

For e-banking screenshots, this helps identify:
- Account balances (usually large, prominent text)
- Transaction amounts (medium-large text)
- Labels and descriptions (smaller, lower priority)

### Example Integration for E-Banking Screenshot Analysis

**Background processing pattern:**

```swift
// In a background service or manager class
actor ScreenshotProcessor {
    private let imageAnalysis = ImageAnalysisService()

    func processScreenshot(_ image: UIImage, for snapshot: ValueSnapshot) async throws -> Double? {
        // Analyze the screenshot
        await imageAnalysis.analyze(image: image)

        guard let results = imageAnalysis.analyzedImage?.textResults else {
            throw ScreenshotProcessingError.analysisFailure
        }

        // Sort by priority (1 = highest)
        let prioritizedText = results.sorted { $0.priority < $1.priority }

        // Filter for high-confidence numeric values
        let numericValues = prioritizedText
            .filter { $0.confidence > 0.8 } // High confidence only
            .filter { $0.priority <= 3 }     // Top 3 priority levels
            .compactMap { extractNumericValue(from: $0.text) }

        // Return the most prominent value
        return numericValues.first
    }

    private func extractNumericValue(from text: String) -> Double? {
        // Remove currency symbols, commas, and extract number
        let cleaned = text.replacingOccurrences(of: "[^0-9.-]", with: "", options: .regularExpression)
        return Double(cleaned)
    }
}
```

**Integration with ValueSnapshot:**

```swift
// When a screenshot is added to a ValueSnapshot
Task {
    if let extractedValue = try? await screenshotProcessor.processScreenshot(
        screenshot,
        for: snapshot
    ) {
        // Update the snapshot value
        snapshot.value = extractedValue
        try? modelContext.save()
    }
}
```

---

## Implementation Checklist

- [ ] Copy 10 files from ImageAnalysis folder
- [ ] Add files to Xcode project (Summa target)
- [ ] Build project to verify framework dependencies
- [ ] Create `ImageAnalysisService-Usage.md` documentation
- [ ] Test on iOS device with sample e-banking screenshot
- [ ] Test on macOS with sample screenshot (verify cross-platform)
- [ ] Test on iPad with larger screen layout
- [ ] Integrate with ValueSnapshot workflow
- [ ] Add background processing logic
- [ ] Test value extraction accuracy with real screenshots

---

## Next Steps

Ready to proceed with implementation:

1. ✅ Copy all 10 files to correct location in Summa
2. ✅ Create comprehensive usage documentation with e-banking screenshot examples
3. ✅ Provide instructions for adding files to Xcode project
4. ✅ Create background processing pattern example
5. ✅ Show value extraction logic for numeric data

**All requirements clarified. Ready to execute when you give the go-ahead.**
