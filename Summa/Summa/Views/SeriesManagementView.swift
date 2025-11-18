//
//  SeriesManagementView.swift
//  Summa
//
//  Created by Till Gartner on 11.11.25.
//

import SwiftUI
import SwiftData

struct SeriesManagementView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    let allSeries: [Series]

    @State private var showingAddSeries = false
    @State private var showingEditSeries: Series?
    @State private var showingDeleteConfirmation: Series?
    @State private var deleteConfirmationText = ""

    var body: some View {
        List {
            Section {
                ForEach(allSeries) { series in
                    SeriesRowView(series: series)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingEditSeries = series
                        }
                    #if os(iOS)
                    .swipeActions {
                        if !series.isDefault {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = series
                                deleteConfirmationText = ""
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    #else
                    .contextMenu {
                        if !series.isDefault {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = series
                                deleteConfirmationText = ""
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    #endif
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        .scrollContentBackground(.visible)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle("Series")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSeries = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(allSeries.count >= 10)
            }
            #else
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSeries = true
                } label: {
                    Label("Add Series", systemImage: "plus")
                }
                .disabled(allSeries.count >= 10)
            }
            #endif
        }
        .sheet(isPresented: $showingAddSeries) {
            SeriesEditView(series: nil)
            #if os(macOS)
            .presentationSizing(.form)
            #endif
        }
        .sheet(item: $showingEditSeries) { series in
            SeriesEditView(series: series)
            #if os(macOS)
            .presentationSizing(.form)
            #endif
        }
        .alert("Delete \"\(showingDeleteConfirmation?.name ?? "")\"?", isPresented: .constant(showingDeleteConfirmation != nil)) {
            TextField("Enter series name to confirm", text: $deleteConfirmationText)
            Button("Cancel", role: .cancel) {
                showingDeleteConfirmation = nil
                deleteConfirmationText = ""
            }
            Button("Delete", role: .destructive) {
                if let series = showingDeleteConfirmation,
                   deleteConfirmationText == series.name,
                   !series.isDefault {
                    modelContext.delete(series)
                    showingDeleteConfirmation = nil
                    deleteConfirmationText = ""
                    try? modelContext.save()
                }
            }
            .disabled(deleteConfirmationText != showingDeleteConfirmation?.name || showingDeleteConfirmation?.isDefault == true)
        } message: {
            if let series = showingDeleteConfirmation {
                Text("This will delete \(series.snapshots?.count ?? 0) entries. This action cannot be undone.\n\nTo confirm, enter the series name:")
            }
        }
    }
}
