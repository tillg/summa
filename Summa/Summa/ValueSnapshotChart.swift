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
    var valueSource: ValueSource
    var color: Color = .orange
    var body: some View {
        let valuesToDraw = valueSource.valueHistory.sorted {
            $0.date < $1.date
        }
            
        Chart {
            ForEach(valuesToDraw, id: \.id) { item in
                LineMark(x: .value("Date", item.date), y: .value("Value", item.value))
                    .foregroundStyle(color)
                    .lineStyle(.init(lineWidth: 10))
                    .lineStyle(.init(lineWidth: 10, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.cardinal)

            }
        }
    }
}

#Preview {
    ValueSnapshotChart(valueSource: ValueSource.examples)
}
