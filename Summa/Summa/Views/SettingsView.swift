//
//  SettingsView.swift
//  Summa
//
//  Created by Till Gartner on 16.11.25.
//

import SwiftUI

#if os(macOS)

/// Settings view for macOS (accessible via ⌘,)
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 400, height: 300)
    }
}

#Preview {
    SettingsView()
}

#endif
