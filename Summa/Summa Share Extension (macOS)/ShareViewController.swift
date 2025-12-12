//
//  ShareViewController.swift
//  Summa Share Extension (macOS)
//

import AppKit
import UniformTypeIdentifiers
import SwiftData

class ShareViewController: NSViewController {

    // Access shared SwiftData container via App Group
    private var modelContainer: ModelContainer?
    private var containerError: Error?

    // MARK: - Lifecycle

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        #if DEBUG
        log("🚀 ShareViewController INIT called")
        #endif
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        #if DEBUG
        log("🚀 ShareViewController INIT (coder) called")
        #endif
    }

    override func loadView() {
        // Create a simple view - we don't need UI, extension runs in background
        self.view = NSView()
        self.view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        #if DEBUG
        log("=== macOS Share Extension viewDidLoad START ===")
        #endif

        // Initialize model container
        do {
            #if DEBUG
            log("Attempting to create model container...")
            #endif

            modelContainer = try ModelContainerFactory.createSharedContainer()

            #if DEBUG
            log("Model container created successfully")
            #endif

            processSharedImage()
        } catch {
            #if DEBUG
            logError("FATAL ERROR creating model container: \(error)")
            #endif

            containerError = error
            showErrorAndDismiss(message: "Unable to access Summa database: \(error.localizedDescription)")
        }
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
                    #if DEBUG
                    logError("Error loading image: \(error)")
                    #endif
                    DispatchQueue.main.async {
                        self.completeRequest(success: false)
                    }
                    return
                }

                // Get image data
                var imageData: Data?

                if let url = item as? URL {
                    imageData = try? Data(contentsOf: url)
                } else if let image = item as? NSImage,
                          let tiffData = image.tiffRepresentation,
                          let bitmap = NSBitmapImageRep(data: tiffData) {
                    imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
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
        // Ensure we have a valid model container
        guard let modelContainer = modelContainer else {
            #if DEBUG
            logError("ERROR: ModelContainer not available")
            #endif
            completeRequest(success: false)
            return
        }

        // Create new snapshot from screenshot - will trigger analysis in main app
        let snapshot = ValueSnapshot.fromScreenshot(imageData, date: Date())

        #if DEBUG
        log("Created snapshot with state: \(snapshot.analysisState)")
        log("Has image data: \(snapshot.sourceImage != nil)")
        #endif

        // Insert and save on background thread
        Task {
            do {
                let context = modelContainer.mainContext
                context.insert(snapshot)
                try context.save()

                #if DEBUG
                log("Snapshot saved to SwiftData")
                #endif

                // Give CloudKit a moment to schedule the export before extension closes
                // Per Apple TN3164: Exports are triggered by system, may need brief delay
                try? await Task.sleep(for: .seconds(0.5))

                await MainActor.run {
                    self.completeRequest(success: true)
                }
            } catch {
                #if DEBUG
                logError("Error saving snapshot: \(error)")
                #endif
                await MainActor.run {
                    self.completeRequest(success: false)
                }
            }
        }
    }

    private func completeRequest(success: Bool) {
        DispatchQueue.main.async {
            #if DEBUG
            log("completeRequest called with success=\(success)")
            #endif

            if success {
                // Just complete immediately - alerts in extensions can be problematic
                self.extensionContext?.completeRequest(returningItems: nil)
            } else {
                self.extensionContext?.cancelRequest(withError: NSError(domain: "SummaShare", code: -1))
            }
        }
    }

    private func showErrorAndDismiss(message: String) {
        DispatchQueue.main.async {
            #if DEBUG
            logError("showErrorAndDismiss: \(message)")
            #endif

            // Just cancel - don't try to show UI in extension
            let error = NSError(domain: "SummaShare", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
            self.extensionContext?.cancelRequest(withError: error)
        }
    }
}
