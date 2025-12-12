//
//  SeriesDeleteConfirmationModifier.swift
//  Summa
//
//  Created by Till Gartner on 23.11.25.
//

import SwiftUI
import SwiftData

/// Reusable view modifier for series deletion confirmation alert
struct SeriesDeleteConfirmationModifier: ViewModifier {
    @Binding var seriesToDelete: Series?
    @Binding var confirmationText: String
    let modelContext: ModelContext
    let onDelete: (() -> Void)?

    @State private var saveError: Error?

    init(
        seriesToDelete: Binding<Series?>,
        confirmationText: Binding<String>,
        modelContext: ModelContext,
        onDelete: (() -> Void)? = nil
    ) {
        self._seriesToDelete = seriesToDelete
        self._confirmationText = confirmationText
        self.modelContext = modelContext
        self.onDelete = onDelete
    }

    func body(content: Content) -> some View {
        content
            .alert(
                "Delete \"\(seriesToDelete?.name ?? "")\"?",
                isPresented: .constant(seriesToDelete != nil)
            ) {
                TextField("Enter series name to confirm", text: $confirmationText)
                Button("Cancel", role: .cancel) {
                    seriesToDelete = nil
                    confirmationText = ""
                }
                Button("Delete", role: .destructive) {
                    if let series = seriesToDelete,
                       confirmationText == series.name,
                       !series.isDefault {
                        // Store values before dismissing
                        let seriesToDeleteName = series.name

                        // Dismiss alert first
                        seriesToDelete = nil
                        confirmationText = ""

                        // Perform deletion after alert dismisses to avoid SwiftUI List animation crash
                        Task { @MainActor in
                            // Wait for alert to dismiss
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

                            // Disable animations to prevent List crash
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                modelContext.delete(series)

                                let result = SaveErrorHandler.save(modelContext, operation: "Delete series '\(seriesToDeleteName)'")
                                if case .failure(let error) = result {
                                    saveError = error
                                } else {
                                    onDelete?()
                                }
                            }
                        }
                    }
                }
                .disabled(confirmationText != seriesToDelete?.name || seriesToDelete?.isDefault == true)
            } message: {
                if let series = seriesToDelete {
                    Text("This will delete \(series.snapshots?.count ?? 0) entries. This action cannot be undone.\n\nTo confirm, enter the series name:")
                }
            }
            .saveErrorAlert(error: $saveError)
    }
}

extension View {
    /// Adds series deletion confirmation alert with name verification
    func seriesDeleteConfirmation(
        seriesToDelete: Binding<Series?>,
        confirmationText: Binding<String>,
        modelContext: ModelContext,
        onDelete: (() -> Void)? = nil
    ) -> some View {
        modifier(SeriesDeleteConfirmationModifier(
            seriesToDelete: seriesToDelete,
            confirmationText: confirmationText,
            modelContext: modelContext,
            onDelete: onDelete
        ))
    }
}
