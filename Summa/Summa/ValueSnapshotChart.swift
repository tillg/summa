//
//  ValueSnapshotChart.swift
//  Summa
//
//  Created by Till Gartner on 10.08.25.
//

import Foundation
import SwiftUI
import Charts


struct ValueSnapshotChart: View {
    
    let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date.now) ?? Date.now
    let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date.now) ?? Date.now
    let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date.now) ?? Date.now
    let everAgo = Calendar.current.date(byAdding: .year, value: -10, to: Date.now) ?? Date.now
    var valueHistory: [ValueSnapshot]
    var color: Color = .orange
    
    @State private var selectedPeriod: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date.now) ?? Date.now
    private var valuesToDraw: [ValueSnapshot] {
        valueHistory.filter() {
            $0.date >= selectedPeriod
        }
        .sorted() {
            $0.date < $1.date
        }
    }
    private var minValueToDraw: Double {
        valuesToDraw.min(by: { $0.value < $1.value })?.value ?? 0
    }
    private var maxValueToDraw: Double {
        valuesToDraw.max(by: { $0.value < $1.value })?.value ?? 0
    }
    
    var body: some View {
        VStack {
            Chart {
                ForEach(valuesToDraw, id: \.id) { item in
                    LineMark(x: .value("Date", item.date), y: .value("Value", item.value))
                        .foregroundStyle(color)
                        //.lineStyle(.init(lineWidth: 10))
                        .lineStyle(.init(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        //.interpolationMethod(.cardinal)
                    
                }
            }
            .chartYScale(domain: [minValueToDraw, maxValueToDraw])
            Picker("", selection: $selectedPeriod) {
                Text("All").tag(everAgo)
                Text("Year").tag(oneYearAgo)
                Text("Month").tag(oneMonthAgo)
                Text("Week").tag(oneWeekAgo)
            }
            .pickerStyle(.segmented)
            .onAppear(){
                print(valuesToDraw)

            }
        }
    }
}

#Preview {
    
//    ValueSnapshotChart(valueSource: ValueSource.examples)
}
