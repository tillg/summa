//
//  SeriesRowView.swift
//  Summa
//
//  Created by Till Gartner on 16.11.25.
//

import SwiftUI
import SwiftData

/// Row view for displaying a series in a list
struct SeriesRowView: View {
    let series: Series

    var body: some View {
        HStack {
            Circle()
                .fill(SeriesManager.shared.colorFromHex(series.color))
                .frame(width: 20, height: 20)

            VStack(alignment: .leading) {
                HStack {
                    Text(series.name)
                        .foregroundStyle(.primary)
                    if series.isDefault {
                        Text("DEFAULT")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .clipShape(.rect(cornerRadius: 4))
                    }
                }
                if let snapshots = series.snapshots,
                   let latestSnapshot = snapshots.sorted(by: >).first,
                   let value = latestSnapshot.value {
                    Text(value.formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR")))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("\(series.snapshots?.count ?? 0) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    // Preview with a dummy series - actual data will come from container
    List {
        SeriesRowView(series: Series(
            name: "Preview Series",
            color: "#007AFF",
            sortOrder: 0,
            isDefault: true
        ))
    }
    .modelContainer(for: [ValueSnapshot.self, Series.self])
}
