# GEMINI Project Context: Summa

This document provides a comprehensive overview of the Summa project, its architecture, and development conventions to be used as instructional context.

## 1. Project Overview

Summa is a personal finance tracking application for Apple platforms (iOS, iPadOS, and macOS). Its core purpose is to allow users to manually track their wealth across various accounts by creating "Value Snapshots" over time.

A key feature is the ability to create a `ValueSnapshot` from a screenshot. The app uses Apple's **Vision framework** to perform Optical Character Recognition (OCR) on the image and a sophisticated internal algorithm to identify and extract the most likely monetary value.

The application is built with a modern, native Apple technology stack:

*   **UI:** SwiftUI, with adaptive layouts for different screen sizes and platforms.
*   **Data Persistence:** SwiftData.
*   **Synchronization:** CloudKit, which syncs data across a user's devices using their iCloud account.
*   **Core Logic:** Swift.

## 2. Architecture

The project follows a clean, service-oriented architecture that separates concerns effectively.

*   **Models (`Summa/Models`):** Defines the core data structures using SwiftData's `@Model` macro. The key models are:
    *   `Series`: Represents a category of values to track (e.g., a specific bank account). Each series has a name, color, and a collection of snapshots.
    *   `ValueSnapshot`: Represents a single data point at a specific time, containing a value, a date, and optionally a source screenshot.

*   **Views (`Summa/Views`):** Contains all SwiftUI views. The UI is component-based and reactive, using `@Environment` and `@Query` to access services and data.
    *   `ContentView`: The main view of the app, which adapts its layout based on the device's horizontal size class.
    *   `ValueSnapshotChart`: A view that visualizes the data.
    *   `ValueSnapshotEditView`: A form for creating or editing entries.

*   **Services (`Summa/Services`):** Encapsulates business logic, making it reusable and testable.
    *   `ScreenshotAnalysisService`: The brain of the app. It contains the pipeline and algorithm for analyzing screenshots, extracting text, and parsing monetary values. It is highly robust, handling various international currency formats.
    *   `ImageAnalysisService`: A lower-level service that acts as a wrapper for the Vision framework to perform OCR.
    *   `CloudKitSyncMonitor`: Monitors the status of CloudKit synchronization and provides feedback to the UI.

*   **Managers (`Summa/Utils/SeriesManager.swift`):** The `SeriesManager` is a singleton that provides utility functions and manages the `Series` data, such as creating the default series.

*   **App Extension (`Summa Share Extension`):** A lightweight share extension that allows users to send images directly to Summa from other apps (like Photos). It creates a `ValueSnapshot` in a "pending" state in the shared SwiftData container, and the main app processes it later. This is a smart decoupling that keeps the extension fast and reliable.

## 3. Building, Running, and Testing

The project is a standard Xcode project.

### Building & Running

*   **Xcode:** The primary method is to open `Summa/Summa.xcodeproj` in Xcode and press the "Run" button (Cmd+R). You will need to select a target device or simulator (e.g., iPhone 15).
*   **Command Line:** You can build the project from the command line using `xcodebuild`.
    ```bash
    xcodebuild build -project Summa/Summa.xcodeproj -scheme Summa -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
    ```

### Testing

The project has a suite of unit tests located in the `SummaTests` directory.

*   **Xcode:** Press **Cmd+U** to run all tests.
*   **Command Line:** Use the `xcodebuild test` command.
    ```bash
    xcodebuild test -project Summa/Summa.xcodeproj -scheme Summa -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
    ```
*   **Convenience Script:** A shell script `clean_and_test.sh` is provided to clean the build folder, build the project, and run the tests in one step.
    ```bash
    ./clean_and_test.sh
    ```

## 4. Development Conventions

*   **SwiftUI & SwiftData:** The project fully embraces modern, declarative development with SwiftUI for the UI and SwiftData for the data layer. Asynchronous operations are handled using `async/await` and `.task` modifiers in SwiftUI.
*   **Dependency Injection:** Services like `ScreenshotAnalysisService` and `CloudKitSyncMonitor` are injected into the SwiftUI `Environment`, making them available to any view that needs them.
*   **Platform-Specific Code:** The code uses `#if os(macOS)` compiler directives to handle differences between iOS and macOS, especially for UI elements like menu commands and window management.
*   **Data Sharing:** An **App Group** is used to create a shared container, allowing both the main app and the Share Extension to access the same SwiftData database file. This is configured in `SummaApp.swift` and `ShareViewController.swift`.
*   **Testing:** Unit tests are written using XCTest. The tests are focused, descriptive, and cover edge cases, indicating a high standard for code quality. The use of `@testable import Summa` is standard practice for accessing `internal` components from the test target.
*   **Logging:** A custom `log()` and `logError()` function are used for debug logging, often wrapped in `#if DEBUG` blocks to ensure they don't ship in release builds.
