//
//  SaveErrorHandler.swift
//  Summa
//
//  Centralized error handling for SwiftData save operations
//

import Foundation
import SwiftData
import SwiftUI

/// Centralized error handler for database save operations
/// Provides logging and user-facing error messages
class SaveErrorHandler {

    /// Result type for save operations
    enum SaveResult {
        case success
        case failure(Error)

        var isSuccess: Bool {
            if case .success = self {
                return true
            }
            return false
        }

        var error: Error? {
            if case .failure(let error) = self {
                return error
            }
            return nil
        }
    }

    /// Attempts to save the model context and returns a Result
    static func save(_ context: ModelContext, operation: String) -> SaveResult {
        do {
            try context.save()
            log("Save successful: \(operation)")
            return .success
        } catch {
            logError("Save failed: \(operation)")
            log("   Error: \(error.localizedDescription)")

            // Log additional details for debugging
            if let nsError = error as NSError? {
                log("   Domain: \(nsError.domain)")
                log("   Code: \(nsError.code)")
                if !nsError.userInfo.isEmpty {
                    log("   UserInfo: \(nsError.userInfo)")
                }
            }

            // TODO: Add analytics/crash reporting here if needed
            // Analytics.logError("save_failed", parameters: ["operation": operation])

            return .failure(error)
        }
    }

    /// User-facing error message for save failures
    static func userMessage(for error: Error) -> String {
        if let nsError = error as NSError? {
            // Check for common SwiftData/CloudKit errors
            switch nsError.domain {
            case "NSCocoaErrorDomain":
                return "Unable to save changes to the database. Please try again."
            case "CKErrorDomain":
                if nsError.code == 2 { // CKErrorNetworkUnavailable
                    return "Network unavailable. Changes will sync when connection is restored."
                } else if nsError.code == 112 { // CKErrorServerRecordChanged
                    return "This item was modified on another device. Please try again."
                }
                return "iCloud sync error. Please check your internet connection."
            default:
                return "Unable to save changes. Please try again."
            }
        }
        return "An unexpected error occurred. Please try again."
    }
}

/// SwiftUI View Modifier for showing save error alerts
struct SaveErrorAlert: ViewModifier {
    @Binding var error: Error?
    let retryAction: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .alert("Save Failed", isPresented: .constant(error != nil)) {
                if let retryAction = retryAction {
                    Button("Retry") {
                        retryAction()
                        error = nil
                    }
                }
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(SaveErrorHandler.userMessage(for: error))
                }
            }
    }
}

extension View {
    /// Adds a save error alert to the view
    /// - Parameters:
    ///   - error: Binding to an optional Error to display
    ///   - retryAction: Optional retry action when user taps "Retry"
    func saveErrorAlert(error: Binding<Error?>, retryAction: (() -> Void)? = nil) -> some View {
        modifier(SaveErrorAlert(error: error, retryAction: retryAction))
    }
}
