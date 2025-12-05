# Fixing Build Errors - Quick Guide

## Current Issue

The test files are showing errors that the methods are `private` even though they've been changed to `internal`. This is because Xcode has cached the old build.

## Solution: Clean Build and Rebuild

### Option 1: In Xcode (Recommended)

1. **Clean Build Folder**:
   - In Xcode menu: `Product > Clean Build Folder` (or press `Shift+Cmd+K`)

2. **Rebuild**:
   - Press `Cmd+B` to build

3. **Run Tests**:
   - Press `Cmd+U` to run all tests

### Option 2: From Command Line

Run the provided script:

```bash
cd /Users/tgartner/git/Summa
./clean_and_test.sh
```

### Option 3: Manual Command Line

```bash
cd /Users/tgartner/git/Summa/Summa

# Clean
xcodebuild clean -project Summa.xcodeproj -scheme Summa

# Build
xcodebuild build -project Summa.xcodeproj -scheme Summa \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Test
xcodebuild test -project Summa.xcodeproj -scheme Summa \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## What Changed

The following methods in `ScreenshotAnalysisService.swift` were changed from `private` to `internal`:

```swift
internal func parseCurrencyString(_ text: String) -> Double?
internal func assessNumberFormat(_ text: String) -> Double
internal func detectsCurrencySymbol(_ text: String) -> Bool
internal func calculateScore(for result: TextRecognitionResult, value: Double) -> Double

internal struct DetectionResult { ... }
internal struct DetectionWeights { ... }
```

## If Errors Persist

1. **Check the file was saved**: Verify `/Users/tgartner/git/Summa/Summa/Summa/Services/ScreenshotAnalysisService.swift` contains `internal` not `private`

2. **Quit and restart Xcode**: Sometimes Xcode needs a full restart to clear caches

3. **Delete DerivedData**:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Summa-*
   ```
   Then rebuild in Xcode

4. **Check test target membership**: Make sure test files are in the `SummaTests` target

## Expected Test Results

After cleaning and rebuilding, you should have:

* **ScreenshotAnalysisServiceTests**: ~40 tests (all should pass)
* **SeriesManagerTests**: ~15 tests (all should pass)
* **SaveErrorHandlerTests**: ~20 tests (all should pass)

**Total**: ~75 tests

## Verifying Success

When tests pass, you'll see:

```
Test Suite 'All tests' passed at ...
Executed 75 tests, with 0 failures (0 unexpected) in X.XXX seconds
```
