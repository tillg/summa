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
    @State private var seriesToDelete: Series?
    @State private var deleteConfirmationText = ""

    var body: some View {
        List {
            Section {
                ForEach(allSeries) { series in
                    Button {
                        showingEditSeries = series
                    } label: {
                        SeriesRowView(series: series)
                    }
                    .buttonStyle(.plain)
                    #if os(iOS)
                    .swipeActions {
                        if !series.isDefault {
                            Button(role: .destructive) {
                                seriesToDelete = series
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
                                seriesToDelete = series
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
                .disabled(allSeries.count >= AppConstants.Series.maxSeriesCount)
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
                .disabled(allSeries.count >= AppConstants.Series.maxSeriesCount)
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
        .seriesDeleteConfirmation(
            seriesToDelete: $seriesToDelete,
            confirmationText: $deleteConfirmationText,
            modelContext: modelContext
        )
    }
}
