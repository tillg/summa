//
//  ImageAnalysisCoordinator.swift
//  Summa
//
//  Coordinates image analysis with three independent processes:
//  1. Generate fingerprints for ALL snapshots missing them
//  2. Extract values from snapshots that haven't been tried yet
//  3. Match series for snapshots with fingerprints but no series
//

import Foundation
import SwiftData
import Observation

/// Coordinates image analysis with three independent, self-querying processes
@Observable
@MainActor
final class ImageAnalysisCoordinator {

    // MARK: - Properties

    private let screenshotAnalyzer = ScreenshotAnalysisService()

    // MARK: - Public Methods

    /// Generate fingerprints for ALL snapshots with images but no fingerprints
    /// Works on both new snapshots AND legacy data
    /// Safe to run repeatedly (idempotent)
    func generateMissingFingerprints(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<ValueSnapshot>(
            predicate: #Predicate {
                $0.sourceImage != nil && $0.fingerprintData == nil
            }
        )

        guard let snapshots = try? modelContext.fetch(descriptor) else {
            #if DEBUG
            log("Failed to fetch snapshots needing fingerprints")
            #endif
            return
        }

        guard !snapshots.isEmpty else {
            return  // Silent - no logging if nothing to do
        }

        #if DEBUG
        log("Generating fingerprints for \(snapshots.count) snapshot(s)")
        #endif

        for snapshot in snapshots {
            guard let imageData = snapshot.sourceImage else { continue }

            do {
                let (fingerprintData, revision) = try await FingerprintService.generateFingerprint(from: imageData)
                snapshot.fingerprintData = fingerprintData
                snapshot.fingerprintRevision = revision

                #if DEBUG
                log("Generated fingerprint for snapshot \(snapshot.id), revision \(revision)")
                #endif
            } catch {
                #if DEBUG
                log("Failed to generate fingerprint for snapshot \(snapshot.id): \(error.localizedDescription)")
                #endif
                // Silent failure - will retry next time
            }

            try? modelContext.save()
        }

        #if DEBUG
        log("Fingerprint generation complete")
        #endif
    }

    /// Extract values from snapshots that haven't been tried yet
    /// Respects humanConfirmed flag (won't process user-confirmed snapshots)
    func extractPendingValues(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<ValueSnapshot>(
            predicate: #Predicate {
                $0.sourceImage != nil &&
                $0.value == nil &&
                $0.valueExtractionAttempted == false &&
                $0.humanConfirmed == false
            }
        )

        guard let snapshots = try? modelContext.fetch(descriptor) else {
            #if DEBUG
            log("Failed to fetch snapshots needing value extraction")
            #endif
            return
        }

        #if DEBUG
        log("Query returned \(snapshots.count) snapshot(s) needing value extraction")
        if snapshots.isEmpty {
            // Debug: Check why nothing matched
            let allWithImages = try? modelContext.fetch(FetchDescriptor<ValueSnapshot>(
                predicate: #Predicate { $0.sourceImage != nil }
            ))
            log("Total snapshots with images: \(allWithImages?.count ?? 0)")
            if let all = allWithImages {
                for snap in all.prefix(3) {
                    log("  Snapshot: value=\(String(describing: snap.value)), attempted=\(snap.valueExtractionAttempted), confirmed=\(snap.humanConfirmed)")
                }
            }
        }
        #endif

        guard !snapshots.isEmpty else {
            return
        }

        #if DEBUG
        log("Extracting values for \(snapshots.count) snapshot(s)")
        #endif

        for snapshot in snapshots {
            // Mark as attempted before trying (ensures we don't retry on failure)
            snapshot.valueExtractionAttempted = true

            await screenshotAnalyzer.analyzeSnapshot(snapshot, modelContext: modelContext)
        }

        #if DEBUG
        log("Value extraction complete")
        #endif
    }

    /// Match series for snapshots with fingerprints but no series
    /// Safe to keep trying (matching is cheap, no harm in retrying)
    func matchUnassignedSeries(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<ValueSnapshot>(
            predicate: #Predicate {
                $0.sourceImage != nil &&
                $0.fingerprintData != nil &&
                $0.series == nil
            }
        )

        guard let snapshots = try? modelContext.fetch(descriptor) else {
            #if DEBUG
            log("Failed to fetch snapshots needing series matching")
            #endif
            return
        }

        guard !snapshots.isEmpty else {
            return  // Silent - no logging if nothing to do
        }

        #if DEBUG
        log("Matching series for \(snapshots.count) snapshot(s)")
        #endif

        // Fetch all snapshots with fingerprints for comparison
        let allFingerprintedDescriptor = FetchDescriptor<ValueSnapshot>(
            predicate: #Predicate { $0.fingerprintData != nil }
        )

        guard let allSnapshots = try? modelContext.fetch(allFingerprintedDescriptor) else {
            #if DEBUG
            log("Failed to fetch snapshots with fingerprints for comparison")
            #endif
            return
        }

        #if DEBUG
        log("Found \(allSnapshots.count) total snapshot(s) with fingerprints for comparison")
        #endif

        var matchedCount = 0
        var unmatchedCount = 0

        for snapshot in snapshots {
            // Try to find matching series
            if let matchedSeries = SeriesMatchingService.findMatchingSeries(
                for: snapshot,
                among: allSnapshots
            ) {
                snapshot.series = matchedSeries
                matchedCount += 1

                #if DEBUG
                log("Matched snapshot \(snapshot.id) to series '\(matchedSeries.name)'")
                #endif
            } else {
                unmatchedCount += 1

                #if DEBUG
                log("No match found for snapshot \(snapshot.id) - leaving series as nil")
                #endif
            }

            try? modelContext.save()
        }

        #if DEBUG
        log("Series matching complete: \(matchedCount) matched, \(unmatchedCount) unmatched")
        #endif
    }
}
