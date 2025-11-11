//
//  ContentView.swift
//  Summa
//
//  Created by Till Gartner on 09.08.25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Query var valueHistory: [ValueSnapshot]
    @State private var showingAddValueSnapshot: Bool = false
    
    var body: some View {
        NavigationStack {
                
            ValueSnapshotChart(valueHistory: valueHistory)
                    .padding(.horizontal)
                List {
                    Section(header: Text("Value history")) {
                        ForEach(valueHistory, id: \.self) { value in
                            HStack {
                                Text("\(value.date.formatted(date: .abbreviated, time: .shortened))")
                                Spacer()
                                Text(value.value.formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR")))
                            }
                        }
                    }
                }
                .navigationTitle("Summa")
                .toolbar {
                    Button("Add entry", systemImage: "plus") {
                        showingAddValueSnapshot = true
                    }
                }
            }
            .sheet(isPresented: $showingAddValueSnapshot) {
                AddValueSnapshotView()
            }
        }
}

#Preview {
    ContentView()
}
