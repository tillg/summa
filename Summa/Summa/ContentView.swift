//
//  ContentView.swift
//  Summa
//
//  Created by Till Gartner on 09.08.25.
//

import SwiftUI


struct ContentView: View {
    @State private var valueSource = ValueSource()
    @State private var showingAddValueSnapshot: Bool = false
    
    var body: some View {
        NavigationStack {
            ValueSnapshotChart(valueSource: valueSource)
                .padding(.horizontal)
            List {
                Text("Value history")
                    .font(.headline)
                ForEach(valueSource.valueHistory, id: \.self) { value in
                    HStack {
                        Text("\(value.date.formatted(date: .abbreviated, time: .shortened))")
                        Spacer()
                        Text(value.value.formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR")))
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
            AddValueSnapshotView(valueSource: valueSource)
        }
    }
}

#Preview {
    ContentView()
}
