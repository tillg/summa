//
//  SummaApp.swift
//  Summa
//
//  Created by Till Gartner on 09.08.25.
//

import SwiftUI
import SwiftData

@main
struct SummaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ValueSnapshot.self, Series.self])
    }
}
