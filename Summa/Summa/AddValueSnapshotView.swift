//
//  AddValueSnapshotView.swift
//  Summa
//
//  Created by Till Gartner on 10.08.25.
//

import Foundation
import SwiftData
import SwiftUI

struct AddValueSnapshotView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query var valueHistory: [ValueSnapshot]
    @Query(sort: \Series.sortOrder) var allSeries: [Series]

    @State private var date = Date.now
    @State private var value: Double = 0
    @State private var notes: String = ""
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

                        TextField("Notes (Optional)", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .navigationTitle("Add Entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            let valueSnapshot = ValueSnapshot(
                                on: date,
                                value: value,
                                notes: notes.isEmpty ? nil : notes,
                                series: selectedSeries
                            )
                            modelContext.insert(valueSnapshot)

                            // Remember last used series
                            if let selectedSeries = selectedSeries {
                                SeriesManager.shared.setLastUsedSeries(selectedSeries)
                            }

                            dismiss()
                        }
                        .disabled(selectedSeries == nil)
                    }
                }
                .onAppear {
                    // Set default series to last used
                    if selectedSeries == nil {
                        selectedSeries = SeriesManager.shared.getLastUsedSeries(from: allSeries)
                    }
                }
        }
    }
}
    
