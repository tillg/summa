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
    @Query(sort: \Series.sortOrder) var allSeries: [Series]
    @State private var showingAddValueSnapshot: Bool = false
    @State private var showingSeriesManagement: Bool = false
    @State private var visibleSeriesIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ValueSnapshotChart(valueHistory: valueHistory, allSeries: allSeries, visibleSeriesIDs: $visibleSeriesIDs)
                    .padding(.horizontal)
                    .padding(.top, 8)

                List {
                    Section(header: Text("Value history")) {
                        ForEach(valueHistory.sorted(by: { $0.date > $1.date }), id: \.self) { value in
                            HStack {
                                if let series = value.series {
                                    Circle()
                                        .fill(SeriesManager.shared.colorFromHex(series.color))
                                        .frame(width: 12, height: 12)
                                }
                                VStack(alignment: .leading) {
                                    Text("\(value.date.formatted(date: .abbreviated, time: .shortened))")
                                    if let series = value.series {
                                        Text(series.name)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text(value.value.formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR")))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Summa")
            .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showingSeriesManagement = true
                        } label: {
                            Image(systemName: "line.3.horizontal")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add entry", systemImage: "plus") {
                            showingAddValueSnapshot = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddValueSnapshot) {
                AddValueSnapshotView()
            }
            .sheet(isPresented: $showingSeriesManagement) {
                SeriesManagementView()
            }
            .onAppear {
                SeriesManager.shared.setModelContext(modelContext)
                // Initialize all series as visible by default
                visibleSeriesIDs = Set(allSeries.map { $0.id })
            }
            .onChange(of: allSeries) { _, newSeries in
                // Ensure newly added series are visible by default
                for series in newSeries {
                    if !visibleSeriesIDs.contains(series.id) {
                        visibleSeriesIDs.insert(series.id)
                    }
                }
            }
        }
}

#Preview {
    ContentView()
}
