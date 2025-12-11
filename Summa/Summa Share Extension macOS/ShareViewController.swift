//
//  ShareViewController.swift
//  Summa Share Extension (macOS)
//

import Cocoa
import SwiftData
import UniformTypeIdentifiers

class ShareViewController: NSViewController {

    private var modelContainer: ModelContainer?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Log execution to verify code runs
        writeLog("🍎 macOS Extension viewDidLoad called!")

        // Create shared model container
        do {
            modelContainer = try ModelContainerFactory.createSharedContainer()
            writeLog("✅ Model container created")
        } catch {
            writeLog("❌ Error creating container: \(error)")
            completeRequest(success: false)
            return
        }

        // Process shared image immediately
        processSharedImage()
    }

    private func processSharedImage() {
        writeLog("📤 processSharedImage called - starting share processing")

        guard let modelContainer = modelContainer else {
            writeLog("❌ No model container")
            completeRequest(success: false)
            return
        }

        // Get the shared image
        if let item = extensionContext?.inputItems.first as? NSExtensionItem,
           let provider = item.attachments?.first,
           provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {

            writeLog("📷 Loading image...")

            provider.loadItem(forTypeIdentifier: UTType.image.identifier,
                            options: nil) { [weak self] (item, error) in
                guard let self = self else { return }

                if let error = error {
                    self.writeLog("❌ Error loading image: \(error)")
                    self.completeRequest(success: false)
                    return
                }

                var imageData: Data?

                // Handle different image item types
                if let url = item as? URL {
                    imageData = try? Data(contentsOf: url)
                } else if let image = item as? NSImage {
                    if let tiffData = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData) {
                        imageData = bitmap.representation(using: .jpeg,
                                                         properties: [.compressionFactor: 0.8])
                    }
                } else if let data = item as? Data {
                    imageData = data
                }

                guard let imageData = imageData else {
                    self.writeLog("❌ Could not get image data")
                    self.completeRequest(success: false)
                    return
                }

                self.writeLog("✅ Image loaded, size: \(imageData.count) bytes")

                // Create and save snapshot
                let snapshot = ValueSnapshot.fromScreenshot(imageData, date: Date())

                Task {
                    do {
                        let context = modelContainer.mainContext
                        context.insert(snapshot)
                        try context.save()

                        self.writeLog("✅ Snapshot saved!")

                        // Give CloudKit time to export (critical for sync)
                        try? await Task.sleep(for: .seconds(0.5))

                        await MainActor.run {
                            self.completeRequest(success: true)
                        }
                    } catch {
                        self.writeLog("❌ Error saving: \(error)")
                        await MainActor.run {
                            self.completeRequest(success: false)
                        }
                    }
                }
            }
        } else {
            writeLog("❌ No image attachment found")
            completeRequest(success: false)
        }
    }

    private func completeRequest(success: Bool) {
        writeLog(success ? "✅ Completing request successfully" : "❌ Completing request with failure")
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func writeLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(),
                                                     dateStyle: .none,
                                                     timeStyle: .medium)
        let logLine = "[🍎 \(timestamp)] \(message)\n"

        // Write to shared App Group log file
        if let logURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.grtnr.Summa")?
            .appendingPathComponent("extension-debug.log") {

            if let data = logLine.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        try? fileHandle.close()
                    }
                } else {
                    try? data.write(to: logURL)
                }
            }
        }

        // Also print to console
        print(logLine)
    }
}
