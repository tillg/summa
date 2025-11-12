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
    @Query(sort: \Series.sortOrder) var allSeries: [Series]

    @State private var showingAddSeries = false
    @State private var showingEditSeries: Series?
    @State private var showingDeleteConfirmation: Series?
    @State private var deleteConfirmationText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(allSeries) { series in
                    Button {
                        showingEditSeries = series
                    } label: {
                        HStack {
                            Circle()
                                .fill(SeriesManager.shared.colorFromHex(series.color))
                                .frame(width: 20, height: 20)

                            VStack(alignment: .leading) {
                                Text(series.name)
                                    .foregroundColor(.primary)
                                if let snapshots = series.snapshots,
                                   let latestSnapshot = snapshots.sorted(by: { $0.date > $1.date }).first {
                                    Text(latestSnapshot.value.formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR")))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Text("\(series.snapshots?.count ?? 0) entries")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = series
                            deleteConfirmationText = ""
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Series")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            }
            .sheet(isPresented: $showingAddSeries) {
                EditSeriesView(series: nil)
            }
            .sheet(item: $showingEditSeries) { series in
                EditSeriesView(series: series)
            }
            .alert("Delete \"\(showingDeleteConfirmation?.name ?? "")\"?", isPresented: .constant(showingDeleteConfirmation != nil)) {
                TextField("Enter series name to confirm", text: $deleteConfirmationText)
                Button("Cancel", role: .cancel) {
                    showingDeleteConfirmation = nil
                    deleteConfirmationText = ""
                }
                Button("Delete", role: .destructive) {
                    if let series = showingDeleteConfirmation,
                       deleteConfirmationText == series.name {
                        modelContext.delete(series)
                        showingDeleteConfirmation = nil
                        deleteConfirmationText = ""
                    }
                }
                .disabled(deleteConfirmationText != showingDeleteConfirmation?.name)
            } message: {
                if let series = showingDeleteConfirmation {
                    Text("This will delete \(series.snapshots?.count ?? 0) entries. This action cannot be undone.\n\nTo confirm, enter the series name:")
                }
            }
        }
    }
}

struct EditSeriesView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Series.sortOrder) var allSeries: [Series]

    let series: Series?

    @State private var name: String = ""
    @State private var selectedColor: String = SeriesManager.predefinedColors[0]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Series name", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(SeriesManager.predefinedColors, id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(SeriesManager.shared.colorFromHex(color))
                                        .frame(width: 44, height: 44)

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
            }
            .navigationTitle(series == nil ? "Add Series" : "Edit Series")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let series = series {
                            series.name = name
                            series.color = selectedColor
                        } else {
                            let newSeries = Series(
                                name: name,
                                color: selectedColor,
                                sortOrder: allSeries.count
                            )
                            modelContext.insert(newSeries)
                        }
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let series = series {
                    name = series.name
                    selectedColor = series.color
                }
            }
        }
    }
}
