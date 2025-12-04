# Automated Tests

I want to build some automated unit tests, starting with non-UI components.
Pls make me a list of easy-to-test components. I would expect that I may have to change the interface of some of them, in order to inject some of the dependencies for testing purposes. I would probably also have to import some pictures into the Xcode environment in order to test the Image analysis services.

## Testing Strategy

### Priority 1: Easy-to-Test Pure Logic (No Dependencies)

These components are already testable without any refactoring:

#### 1. **ScreenshotAnalysisService - Currency Parsing** ⭐️ HIGHEST PRIORITY
**File:** `Services/ScreenshotAnalysisService.swift`

**What to test:**
- `parseCurrencyString(_ text:)` method (lines 258-313)
- Test cases:
  - US format: "$1,234.56" → 1234.56
  - European format: "1.234,56 EUR" → 1234.56
  - Swiss format: "1'234.56 CHF" → 1234.56
  - Edge cases: "€12,50", "$1234", "1,234", multiple separators
  - Invalid inputs: "abc", "", "1.2.3.4"
  - Boundary values: 0, very large numbers, negative detection

**Refactoring needed:** Make `parseCurrencyString` internal/public instead of private

**Test difficulty:** ⭐️ EASY - Pure function, no dependencies

#### 2. **ScreenshotAnalysisService - Format Assessment**
**File:** `Services/ScreenshotAnalysisService.swift`

**What to test:**
- `assessNumberFormat(_ text:)` method (lines 234-255)
- `detectsCurrencySymbol(_ text:)` method (lines 228-232)
- Test scoring logic for different number formats

**Refactoring needed:** Make methods internal/public

**Test difficulty:** ⭐️ EASY - Pure functions

#### 3. **SeriesManager - Color Utilities**
**File:** `Utils/SeriesManager.swift`

**What to test:**
- `colorFromHex(_ hex:)` - Test hex string to Color conversion
- Color palette consistency
- Edge cases: invalid hex strings, short/long formats

**Refactoring needed:** None (already accessible via singleton)

**Test difficulty:** ⭐️ EASY - Pure logic

#### 4. **PlatformImage - Image Compression**
**File:** `Utils/PlatformImage.swift`

**What to test:**
- `compressedJPEGData(maxSizeKB:)` extension method
- Test that images are compressed to target size
- Test compression quality degradation
- Test with various image sizes

**Refactoring needed:** None

**Test difficulty:** ⭐️⭐️ MEDIUM - Requires test images as resources

**Test images needed:**
- Large photo (5MB+)
- Medium photo (1-2MB)
- Small photo (<500KB)
- Wide/tall aspect ratios

#### 5. **ValueSnapshot - Model Logic**
**File:** `Models/ValueSnapshot.swift`

**What to test:**
- `fromScreenshot(_ imageData:, date:)` factory method
- State transitions (analysisState enum)
- Computed properties (analysisState, dataSource)
- Comparison operators (<, ==)
- Hash function

**Refactoring needed:** None

**Test difficulty:** ⭐️⭐️ MEDIUM - Requires SwiftData test context

#### 6. **Series - Model Logic**
**File:** `Models/Series.swift`

**What to test:**
- `isDefault` computed property
- Comparison operators
- Hash function

**Refactoring needed:** None

**Test difficulty:** ⭐️⭐️ MEDIUM - Requires SwiftData test context

### Priority 2: Testable with Dependency Injection

These require refactoring to inject dependencies:

#### 7. **SaveErrorHandler**
**File:** `Utils/SaveErrorHandler.swift`

**What to test:**
- `userMessage(for error:)` - Test error message generation for different error types
- Test NSCocoaErrorDomain handling
- Test CKErrorDomain handling (CloudKit errors)

**Refactoring needed:** None (already static methods)

**Test difficulty:** ⭐️ EASY - Pure logic, just need to create test NSError objects

#### 8. **ScreenshotAnalysisService - Score Calculation**
**File:** `Services/ScreenshotAnalysisService.swift`

**What to test:**
- `calculateScore(for:value:)` method (lines 201-226)
- Test weighting algorithm
- Test that high-confidence, high-priority, formatted values score highest

**Refactoring needed:**
- Make `calculateScore` internal/public
- Make `DetectionWeights` accessible for testing (inject or expose)

**Test difficulty:** ⭐️⭐️ MEDIUM - Need to create mock `TextRecognitionResult` objects

#### 9. **ImageAnalysis - Font Size Analyzer**
**File:** `Services/ImageAnalysis/Internal/IAFontSizeAnalyzer.swift`

**What to test:**
- Priority assignment based on text size
- Handling of tied heights
- Edge cases: empty input, single item

**Refactoring needed:** Minimal - already using structs

**Test difficulty:** ⭐️⭐️ MEDIUM - Need mock text recognition results

### Priority 3: Integration Tests (Require Dependencies)

#### 10. **ScreenshotAnalysisService - End-to-End**
**File:** `Services/ScreenshotAnalysisService.swift`

**What to test:**
- Full analysis pipeline with real screenshot images
- Value extraction accuracy
- State transitions during analysis

**Refactoring needed:**
- Inject `ImageAnalysisService` dependency (currently hardcoded)
- Make analysis synchronous for testing (remove async delays)
- Or: Create test-specific init with mock ImageAnalysisService

**Test difficulty:** ⭐️⭐️⭐️ HARD - Requires:
  - Test screenshots with known values
  - SwiftData test container
  - Mock or real ImageAnalysisService
  - Async testing

**Test images needed:**
- Bank balance screenshot with clear value
- Stock portfolio screenshot
- Crypto wallet screenshot
- Screenshots with multiple numbers (test priority selection)
- Screenshots with no monetary values (failure case)

#### 11. **ImageAnalysisService**
**File:** `Services/ImageAnalysis/ImageAnalysisService.swift`

**What to test:**
- Text recognition accuracy
- Object recognition
- Face detection

**Test difficulty:** ⭐️⭐️⭐️⭐️ VERY HARD
- Relies on Vision framework (system dependency)
- Non-deterministic results
- Better suited for integration tests, not unit tests

### Priority 4: Not Recommended for Unit Testing

These are better tested via UI tests or not worth testing:

- **CloudKitSyncMonitor** - Requires CloudKit, better tested manually
- **Logger** - Simple wrappers, not worth testing
- **AppConstants** - Just constants
- **View components** - Use UI tests or Previews

## Recommended Testing Approach

### Phase 1: Pure Logic (Week 1)
1. Currency parsing (ScreenshotAnalysisService)
2. Format assessment and currency detection
3. SeriesManager color utilities
4. SaveErrorHandler error messages

**Goal:** Build confidence in core parsing logic

### Phase 2: Model Layer (Week 2)
5. ValueSnapshot factory methods and state logic
6. Series model logic
7. PlatformImage compression

**Setup needed:**
- SwiftData in-memory test container
- Test image resources

### Phase 3: Service Layer (Week 3)
8. ScreenshotAnalysisService score calculation
9. Font size analyzer
10. Mock-based tests for analysis service

**Setup needed:**
- Mock objects for Vision results
- Test utilities for creating fixtures

### Phase 4: Integration (Future)
11. End-to-end screenshot analysis
12. CloudKit sync scenarios (optional)

## Refactoring Required

### Make Methods Testable

**ScreenshotAnalysisService.swift:**
```swift
// Change these from private to internal for testing:
internal func parseCurrencyString(_ text: String) -> Double?
internal func assessNumberFormat(_ text: String) -> Double
internal func detectsCurrencySymbol(_ text: String) -> Bool
internal func calculateScore(for result: TextRecognitionResult, value: Double) -> Double
internal func extractMonetaryValue(from textResults: [TextRecognitionResult]) -> DetectionResult?

// Make DetectionResult accessible
internal struct DetectionResult { ... }
```

**Alternative approach:** Create a separate `CurrencyParser` class that's testable by design:
```swift
// New file: Utils/CurrencyParser.swift
class CurrencyParser {
    func parse(_ text: String) -> Double?
    func assessFormat(_ text: String) -> Double
    func hasCurrencySymbol(_ text: String) -> Bool
}
```

### Dependency Injection for ScreenshotAnalysisService

**Current:**
```swift
private let imageAnalysis = ImageAnalysisService()
```

**Refactored:**
```swift
private let imageAnalysis: ImageAnalysisProtocol

init(imageAnalysis: ImageAnalysisProtocol = ImageAnalysisService()) {
    self.imageAnalysis = imageAnalysis
}
```

## Test Resources Needed

### Images to Add to Test Bundle
1. **currency_usd_simple.png** - Screenshot with "$1,234.56"
2. **currency_eur_formatted.png** - Screenshot with "1.234,56 EUR"
3. **currency_chf_apostrophe.png** - Screenshot with "1'234.56 CHF"
4. **multiple_numbers.png** - Screenshot with several numbers (test priority)
5. **no_currency.png** - Screenshot with no monetary values
6. **bank_statement.png** - Real bank balance screenshot
7. **large_image.jpg** - 5MB+ photo for compression testing
8. **small_image.jpg** - <100KB photo

### Mock Data Fixtures
- Sample `TextRecognitionResult` objects
- Sample `ValueSnapshot` objects in various states
- Sample `Series` objects

## Testing Utilities to Create

```swift
// TestHelpers/SwiftDataTestContainer.swift
class SwiftDataTestContainer {
    static func create() -> ModelContainer
}

// TestHelpers/MockImageAnalysisService.swift
class MockImageAnalysisService: ImageAnalysisProtocol {
    var mockResults: AnalyzedImage?
    var mockError: Error?
}

// TestHelpers/TextRecognitionResultBuilder.swift
class TextRecognitionResultBuilder {
    func withText(_ text: String) -> Self
    func withConfidence(_ confidence: Float) -> Self
    func withPriority(_ priority: Int) -> Self
    func build() -> TextRecognitionResult
}
```

## Coverage Goals

- **Phase 1:** 80%+ coverage on currency parsing logic
- **Phase 2:** 70%+ coverage on model layer
- **Phase 3:** 60%+ coverage on service layer
- **Overall:** 50%+ code coverage (realistic for Swift UI app)

## Benefits of This Approach

1. **Quick wins** - Start with pure functions, see results immediately
2. **Build confidence** - Test critical parsing logic first
3. **Incremental** - Each phase adds value without blocking progress
4. **Pragmatic** - Focuses on high-value, testable components
5. **Maintainable** - Tests document expected behavior

## Notes

- Focus on **business logic**, not framework wrappers
- Don't test SwiftUI views with unit tests (use Previews + manual testing)
- Don't test third-party frameworks (Vision, CloudKit)
- Keep tests **fast** (<10ms per test for logic, <100ms for model tests)
- Use **descriptive test names**: `testParseCurrencyString_USFormat_ReturnsCorrectValue()`
