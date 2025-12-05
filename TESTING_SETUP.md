# Testing Setup Guide

This guide explains how to set up and run the automated tests for Summa.

## Test Files Created

The following test files have been created in the `SummaTests` directory:

1. **ScreenshotAnalysisServiceTests.swift** - Tests for currency parsing and format assessment
2. **SeriesManagerTests.swift** - Tests for color utilities
3. **SaveErrorHandlerTests.swift** - Tests for error message generation

## Setting Up the Test Target in Xcode

Since the test files have been created but need to be added to the Xcode project, follow these steps:

### Step 1: Add Test Target

1. Open `Summa.xcodeproj` in Xcode
2. Select the project in the Project Navigator (blue icon at the top)
3. Click the "+" button at the bottom of the targets list
4. Select "Unit Testing Bundle" under iOS
5. Name it: `SummaTests`
6. Set the Target to be Tested: `Summa`
7. Click "Finish"

### Step 2: Add Test Files to the Test Target

1. In Xcode, right-click on the `SummaTests` group in the Project Navigator
2. Select "Add Files to 'Summa'..."
3. Navigate to the `SummaTests` folder
4. Select all three test files:
   - `ScreenshotAnalysisServiceTests.swift`
   - `SeriesManagerTests.swift`
   - `SaveErrorHandlerTests.swift`
5. Make sure "Copy items if needed" is **unchecked** (files are already in place)
6. Ensure the target membership shows `SummaTests` checked
7. Click "Add"

### Step 3: Configure Test Target Settings

1. Select the `SummaTests` target
2. Go to the "Build Settings" tab
3. Search for "Test Host"
4. Ensure it's set to: `$(BUILT_PRODUCTS_DIR)/Summa.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Summa`

### Step 4: Link Against the Main App

1. Select the `SummaTests` target
2. Go to the "Build Phases" tab
3. Expand "Link Binary With Libraries"
4. The test target should automatically link against the Summa app

## Running the Tests

### Run All Tests

1. In Xcode, press `Cmd+U` to run all tests
2. Or: Select `Product > Test` from the menu

### Run Specific Test File

1. Open the test file you want to run
2. Click the diamond icon next to the class name to run all tests in that file
3. Or click the diamond icon next to a specific test method to run just that test

### Run Tests from Command Line

```bash
# Build and run all tests
xcodebuild test -project Summa.xcodeproj -scheme Summa -destination 'platform=iOS Simulator,name=iPhone 15'

# Or if you have xcrun available:
xcrun xcodebuild test -project Summa.xcodeproj -scheme Summa -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Test Coverage

The Priority 1 tests cover:

### ✅ ScreenshotAnalysisService (40+ tests)
- Currency parsing for multiple formats (US, European, Swiss)
- Currency symbol detection (17 different currency symbols)
- Number format assessment (scoring algorithm)
- Edge cases and boundary values

### ✅ SeriesManager (15+ tests)
- Hex to Color conversion
- Predefined color palette validation
- Edge cases (invalid hex, empty strings, etc.)

### ✅ SaveErrorHandler (20+ tests)
- Error message generation for different error domains
- CloudKit error handling
- SwiftData/CoreData error handling
- SaveResult enum behavior

## Understanding Test Results

### Green Checkmark ✓
Test passed successfully

### Red X ✗
Test failed - check the console output for assertion details

### Yellow Warning ⚠
Test was skipped or had non-fatal issues

## Continuous Integration

To run tests in CI/CD:

```yaml
# Example GitHub Actions workflow
- name: Run Unit Tests
  run: |
    xcodebuild test \
      -project Summa.xcodeproj \
      -scheme Summa \
      -destination 'platform=iOS Simulator,name=iPhone 15' \
      -enableCodeCoverage YES
```

## Troubleshooting

### Tests Not Finding Symbols from Main App

Make sure you're using `@testable import Summa` at the top of each test file.

### "No such module 'Summa'" Error

1. Ensure the test target is properly linked to the main app target
2. Clean build folder: `Cmd+Shift+K`
3. Rebuild: `Cmd+B`

### Tests Timing Out

Some tests use `@MainActor` annotations because they test main-thread-only code. Make sure your test target has proper threading support enabled.

## Next Steps

After verifying Priority 1 tests pass, consider implementing:

- **Priority 2:** Model layer tests (ValueSnapshot, Series)
- **Priority 3:** Service layer integration tests
- **Priority 4:** UI tests using XCTest UI

See `Specs/06_AUTOMATED_TESTS.md` for the complete testing roadmap.
