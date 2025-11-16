//
//  ValueSnapshotFormView.swift
//  Summa
//
//  Created by Till Gartner on 10.08.25.
//

import Foundation
import SwiftData
import SwiftUI

struct ValueSnapshotFormView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Series.sortOrder) var allSeries: [Series]

    let snapshot: ValueSnapshot?

    @State private var date = Date.now
    @State private var value: Double = 0
    @State private var selectedSeries: Series?

    var body: some View {
            NavigationStack {
                Form {
                    Section("Series") {
                        if !allSeries.isEmpty {
                            Picker("Series", selection: $selectedSeries) {
                                ForEach(allSeries) { series in
                                    HStack {
                                        Circle()
                                            .fill(SeriesManager.shared.colorFromHex(series.color))
                                            .frame(width: 12, height: 12)
                                        Text(series.name)
                                    }
                                    .tag(series as Series?)
                                }
                            }
                        } else {
                            Text("No series available")
                                .foregroundColor(.secondary)
                        }
                    }

                    Section("Details") {
                        TextField("Value", value: $value, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                            .keyboardType(.decimalPad)

                        DatePicker("Date", selection: $date)
                    }
                }
                .navigationTitle(snapshot == nil ? "Add Entry" : "Edit Entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            if let snapshot = snapshot {
                                // Edit existing snapshot
                                snapshot.date = date
                                snapshot.value = value
                                snapshot.series = selectedSeries
                            } else {
                                // Create new snapshot
                                let valueSnapshot = ValueSnapshot(
                                    on: date,
                                    value: value,
                                    series: selectedSeries
                                )
                                modelContext.insert(valueSnapshot)
                            }

                            // Remember last used series
                            if let selectedSeries = selectedSeries {
                                SeriesManager.shared.setLastUsedSeries(selectedSeries)
                            }

                            try? modelContext.save()
                            dismiss()
                        }
                        .disabled(selectedSeries == nil)
                    }
                }
                .onAppear {
                    if let snapshot = snapshot {
                        // Editing existing snapshot
                        date = snapshot.date
                        value = snapshot.value
                        selectedSeries = snapshot.series
                    } else {
                        // Adding new snapshot - set default series to last used
                        if selectedSeries == nil {
                            selectedSeries = SeriesManager.shared.getLastUsedSeries(from: allSeries)
                        }
                    }
                }
        }
    }
}
    
