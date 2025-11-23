//
//  ShareViewController.swift
//  Summa Share Extension
//

import UIKit
import Social
import UniformTypeIdentifiers
import SwiftData

class ShareViewController: UIViewController {

    // App Group identifier for shared container
    private let appGroupIdentifier = "group.com.grtnr.Summa"

    // Access shared SwiftData container via App Group
    lazy var modelContainer: ModelContainer = {
        let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
            .appending(path: "Summa.sqlite")

        let config = ModelConfiguration(url: storeURL)
        return try! ModelContainer(
            for: ValueSnapshot.self, Series.self,
            configurations: config
        )
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        processSharedImage()
    }

    private func processSharedImage() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            completeRequest(success: false)
            return
        }

        // Check if it's an image
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier) { [weak self] (item, error) in
                guard let self = self else { return }

                if let error = error {
                    print("Error loading image: \(error)")
                    DispatchQueue.main.async {
                        self.completeRequest(success: false)
                    }
                    return
                }

                // Get image data
                var imageData: Data?

                if let url = item as? URL {
                    imageData = try? Data(contentsOf: url)
                } else if let image = item as? UIImage {
                    imageData = image.jpegData(compressionQuality: 0.8)
                } else if let data = item as? Data {
                    imageData = data
                }

                guard let imageData = imageData else {
                    DispatchQueue.main.async {
                        self.completeRequest(success: false)
                    }
                    return
                }

                // Create pending snapshot
                self.createPendingSnapshot(with: imageData)
            }
        } else {
            completeRequest(success: false)
        }
    }

    private func createPendingSnapshot(with imageData: Data) {
        // Create new pending snapshot
        let snapshot = ValueSnapshot(
            on: Date(),
            value: nil,  // No value yet - pending state
            series: nil,
            processingState: .pending
        )
        snapshot.sourceImage = imageData
        snapshot.imageAttachedDate = Date()

        // Insert and save on background thread
        Task {
            do {
                let context = modelContainer.mainContext
                context.insert(snapshot)
                try context.save()

                await MainActor.run {
                    self.completeRequest(success: true)
                }
            } catch {
                print("Error saving snapshot: \(error)")
                await MainActor.run {
                    self.completeRequest(success: false)
                }
            }
        }
    }

    private func completeRequest(success: Bool) {
        DispatchQueue.main.async {
            if success {
                // Show brief success message
                let alert = UIAlertController(
                    title: "Saved to Summa",
                    message: "Screenshot ready to process",
                    preferredStyle: .alert
                )
                self.present(alert, animated: true) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.extensionContext?.completeRequest(returningItems: nil)
                    }
                }
            } else {
                self.extensionContext?.cancelRequest(withError: NSError(domain: "SummaShare", code: -1))
            }
        }
    }
}
