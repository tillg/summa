# ![summa logo](Summa/Summa/Assets.xcassets/summa.logo.appiconset/summa-totals-warm-ipad-40x40.png) Summa

Keeping track of my wealth across multiple bank accounts, stock accounts and other value stores. Dead simple, no API integration, simple, manual updates.

Built for iOS and macOS with iCloud sync.

## Features

* Multi-platform: iOS, iPad, macOS
* iCloud sync via CloudKit
* Automatic screenshot analysis with Vision framework
* Multiple series tracking with color-coded charts
* Share extension for quick data entry from screenshots

## Testing

Summa includes automated unit tests for core business logic components.

### Running Tests

```bash
# In Xcode: Press Cmd+U to run all tests

# Or from command line:
xcodebuild test -project Summa/Summa.xcodeproj -scheme Summa \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Test Coverage

Priority 1 tests (✅ implemented):

* **ScreenshotAnalysisService**: Currency parsing, format assessment, symbol detection (40+ tests)
* **SeriesManager**: Color utilities and hex conversion (15+ tests)
* **SaveErrorHandler**: Error message generation for different error types (20+ tests)

For detailed setup instructions and test configuration, see [TESTING_SETUP.md](TESTING_SETUP.md).

## To dos

* Syncing with iCloud" --> nasty error when not logged in
* Have a nicer version of the spinner, maybe a curve that ius moving randomly
* Automatically recognize the series to which a Screenshot belongs
* Have a unit / currency per series
