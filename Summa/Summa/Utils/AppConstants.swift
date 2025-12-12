//
//  AppConstants.swift
//  Summa
//
//  Created by Till Gartner on 23.11.25.
//

import Foundation

/// Centralized constants used throughout the app
enum AppConstants {

    // MARK: - App Group

    /// App Group identifier for shared container between main app and Share Extension
    static let appGroupIdentifier = "group.com.grtnr.Summa"

    /// Database filename
    static let databaseFileName = "Summa.sqlite"

    // MARK: - Chart Configuration

    enum Chart {
        /// Line width for chart lines
        static let lineWidth: CGFloat = 5

        /// Minimum height for chart area
        static let minHeight: CGFloat = 100

        // MARK: Time Periods

        /// Number of days for "Week" period
        static let weekDays = -7

        /// Number of months for "Month" period
        static let monthDuration = -1

        /// Number of years for "Year" period
        static let yearDuration = -1

        /// Number of years to represent "All time" (far back enough to catch all data)
        static let allTimeDuration = -10
    }

    // MARK: - Series Configuration

    enum Series {
        /// Maximum number of series allowed in the app
        static let maxSeriesCount = 10
    }

    // MARK: - Image Configuration

    enum Image {
        /// Maximum compressed JPEG size in kilobytes
        static let maxCompressedSizeKB = 1024
    }

    // MARK: - Analysis Configuration

    enum Analysis {
        /// Minimum time to show "analyzing" state for user feedback
        /// Set to 0 to show actual analysis speed
        #if DEBUG
        static let minimumAnalysisTime: TimeInterval = 0.0
        #else
        static let minimumAnalysisTime: TimeInterval = 0.0
        #endif

        /// Initial UI refresh delay before starting analysis
        static let uiRefreshDelay: TimeInterval = 0.0
    }

    // MARK: - UI Configuration

    enum UI {
        #if os(macOS)
        /// Default window size for macOS
        static let defaultWindowWidth: CGFloat = 1200
        static let defaultWindowHeight: CGFloat = 800
        static let minWindowWidth: CGFloat = 800
        static let minWindowHeight: CGFloat = 600
        #endif

        /// Circle size for color picker
        static let colorPickerCircleSize: CGFloat = 44

        /// Color picker grid spacing
        static let colorPickerSpacing: CGFloat = 12

        /// Series indicator circle size
        static let seriesIndicatorSize: CGFloat = 12
    }
}
