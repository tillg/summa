//
//  ModelContainerFactory.swift
//  Summa
//
//  Shared factory for creating ModelContainer with consistent CloudKit configuration
//  Used by both main app and share extension to ensure data syncs properly
//

import SwiftData
import Foundation

enum ModelContainerFactory {
    /// Creates the shared ModelContainer with CloudKit sync
    /// Used by both main app and share extension
    static func createSharedContainer() throws -> ModelContainer {
        guard let appGroupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier) else {
            throw NSError(
                domain: "ModelContainerFactory",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to access App Group container"]
            )
        }

        let storeURL = appGroupURL.appending(path: AppConstants.databaseFileName)

        #if DEBUG
        log("SwiftData store location: \(storeURL.path)")
        #endif

        let config = ModelConfiguration(
            url: storeURL,
            cloudKitDatabase: .private("iCloud.com.grtnr.Summa")
        )

        let container = try ModelContainer(
            for: ValueSnapshot.self, Series.self,
            configurations: config
        )

        #if DEBUG
        log("ModelContainer created successfully with CloudKit sync")
        #endif

        return container
    }
}
