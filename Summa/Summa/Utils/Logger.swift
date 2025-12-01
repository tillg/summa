//
//  Logger.swift
//  Summa
//
//  Simple logging utility with timestamp and caller information
//

import Foundation
import os.log

/// Global logging function with timestamp and caller information
/// - Parameters:
///   - message: The message to log
///   - function: The calling function (automatically captured)
///   - file: The calling file (automatically captured)
///   - line: The calling line number (automatically captured)
func log(
    _ message: String,
    function: String = #function,
    file: String = #file,
    line: Int = #line
) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    formatter.timeZone = TimeZone.current

    let timestamp = formatter.string(from: Date())

    // Extract just the filename without path
    let filename = (file as NSString).lastPathComponent

    // Extract the class/struct name if present in the filename
    let className = filename.replacingOccurrences(of: ".swift", with: "")

    print("[\(timestamp)] [\(className).\(function):\(line)] \(message)")
}

// MARK: - Error Logging

/// Private logger for error messages
private let errorLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Summa", category: "Error")

/// Log an error message (displays in red/orange in Xcode console)
/// - Parameters:
///   - message: The error message to log
///   - function: The calling function (automatically captured)
///   - file: The calling file (automatically captured)
///   - line: The calling line number (automatically captured)
func logError(
    _ message: String,
    function: String = #function,
    file: String = #file,
    line: Int = #line
) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    formatter.timeZone = TimeZone.current

    let timestamp = formatter.string(from: Date())

    // Extract just the filename without path
    let filename = (file as NSString).lastPathComponent

    // Extract the class/struct name if present in the filename
    let className = filename.replacingOccurrences(of: ".swift", with: "")

    // Use OSLog which Xcode displays with color coding
    let formattedMessage = "[\(timestamp)] [\(className).\(function):\(line)] \(message)"
    errorLogger.error("\(formattedMessage, privacy: .public)")
}
