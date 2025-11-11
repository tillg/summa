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
    
    @State private var date = Date.now
    @State private var value: Double = 0

    var body: some View {
            NavigationStack {
                Form {
                    DatePicker("Date", selection: $date)
                    TextField("Value", value: $value, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                        .keyboardType(.decimalPad)
                }
                .navigationTitle("Add Snapshot")
                .toolbar {
                    Button("Save") {
                        let valueSnapshot = ValueSnapshot(on:date, value: value)
                        modelContext.insert(valueSnapshot)
                        dismiss()
                    }
                }
        }
    }
}
    
