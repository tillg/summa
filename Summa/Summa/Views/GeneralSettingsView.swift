//
//  GeneralSettingsView.swift
//  Summa
//
//  Created by Till Gartner on 16.11.25.
//

import SwiftUI

#if os(macOS)

/// General settings panel showing app information
struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("Summa v1.0")
                    .font(.headline)
                Text("Personal wealth tracking for iOS, iPadOS, and macOS")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding()
    }
}

#Preview {
    GeneralSettingsView()
        .frame(width: 400, height: 300)
}

#endif
