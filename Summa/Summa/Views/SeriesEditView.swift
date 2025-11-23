//
//  EditSeriesView.swift
//  Summa
//
//  Created by Till Gartner on 16.11.25.
//

import SwiftUI
import SwiftData

/// View for adding or editing a series
struct SeriesEditView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Series.sortOrder) var allSeries: [Series]

    let series: Series?

    @State private var name: String = ""
    @State private var selectedColor: String = SeriesManager.predefinedColors[0]
    @State private var isDefault: Bool = false
    @State private var seriesToDelete: Series?
    @State private var deleteConfirmationText = ""
    @State private var saveError: Error?

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Series name", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: AppConstants.UI.colorPickerCircleSize))], spacing: AppConstants.UI.colorPickerSpacing) {
                        ForEach(SeriesManager.predefinedColors, id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(SeriesManager.shared.colorFromHex(color))
                                        .frame(width: AppConstants.UI.colorPickerCircleSize, height: AppConstants.UI.colorPickerCircleSize)

                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                            .fontWeight(.bold)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Toggle("Set as default series", isOn: $isDefault)
                        .disabled(series?.isDefault == true && allSeries.count <= 1)
                } footer: {
                    if series?.isDefault == true && allSeries.count <= 1 {
                        Text("This is the only series, so it must remain the default. The default series is used for new entries and cannot be deleted.")
                            .font(.caption)
                    } else {
                        Text("The default series is used for new entries and cannot be deleted.")
                            .font(.caption)
                    }
                }

                // Delete section - only show when editing an existing non-default series
                if let series = series, !series.isDefault {
                    Section {
                        Button(role: .destructive) {
                            seriesToDelete = series
                        } label: {
                            Label("Delete Series", systemImage: "trash")
                        }
                    } footer: {
                        Text("This will delete \(series.snapshots?.count ?? 0) entries. This action cannot be undone.")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(series == nil ? "Add Series" : "Edit Series")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(macOS)
            .padding()
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                }
                #endif
            }
            .onAppear {
                if let series = series {
                    name = series.name
                    selectedColor = series.color
                    isDefault = series.isDefault
                }
            }
            .seriesDeleteConfirmation(
                seriesToDelete: $seriesToDelete,
                confirmationText: $deleteConfirmationText,
                modelContext: modelContext,
                onDelete: { dismiss() }
            )
            .saveErrorAlert(error: $saveError, retryAction: saveChanges)
        }
    }

    // MARK: - Helper Methods

    private func saveChanges() {
        if let series = series {
            series.name = name
            series.color = selectedColor

            // Handle default series change
            if isDefault && !series.isDefault {
                // User checked the default flag - set this as default and clear all others
                SeriesManager.shared.setDefaultSeries(series, allSeries: allSeries, context: modelContext)
            } else if !isDefault && series.isDefault {
                // User unchecked the default flag
                series.isDefault = false

                // Ensure at least one series is default - set first non-current series as default
                let otherSeries = allSeries.filter { $0.id != series.id }
                if let firstOther = otherSeries.first {
                    firstOther.isDefault = true
                }
            }
        } else {
            let newSeries = Series(
                name: name,
                color: selectedColor,
                sortOrder: allSeries.count,
                isDefault: isDefault
            )
            modelContext.insert(newSeries)

            // If this is marked as default, ensure no other series is default
            if isDefault {
                SeriesManager.shared.setDefaultSeries(newSeries, allSeries: allSeries + [newSeries], context: modelContext)
            }
        }

        // Save changes
        let result = SaveErrorHandler.save(modelContext, operation: "Save series '\(name)'")
        if case .failure(let error) = result {
            saveError = error
            return
        }

        dismiss()
    }
}

#Preview {
    NavigationStack {
        SeriesEditView(series: nil)
    }
    .modelContainer(for: [ValueSnapshot.self, Series.self])
}
