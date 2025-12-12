//
//  SeriesMatchingService.swift
//  Summa
//
//  Service for matching snapshots to series based on visual fingerprints
//

import Foundation
import SwiftData

/// Service for matching snapshots to series using visual fingerprints
class SeriesMatchingService {

    /// Distance threshold for auto-assignment
    /// If best match distance < 0.25, auto-assign to that series
    /// If best match distance ≥ 0.25, leave series as nil for manual assignment
    static let autoAssignmentThreshold: Float = 0.25

    /// Result of series matching
    struct MatchResult {
        let series: Series?
        let averageDistance: Float?
        let matchedCount: Int
    }

    /// Find the best matching series for a snapshot based on fingerprint comparison
    /// - Parameters:
    ///   - snapshot: The snapshot to match (must have fingerprintData and fingerprintRevision)
    ///   - allSnapshots: All snapshots from all series with fingerprints
    /// - Returns: The best matching series, or nil if no match meets threshold
    static func findMatchingSeries(
        for snapshot: ValueSnapshot,
        among allSnapshots: [ValueSnapshot]
    ) -> Series? {
        // Validate that snapshot has fingerprint data
        guard let targetFingerprintData = snapshot.fingerprintData,
              let targetRevision = snapshot.fingerprintRevision else {
            return nil
        }

        // Group snapshots by series and filter by matching revision
        var seriesSnapshots: [Series: [ValueSnapshot]] = [:]

        for otherSnapshot in allSnapshots {
            // Skip the target snapshot itself
            if otherSnapshot.id == snapshot.id {
                continue
            }

            // Only compare snapshots with same fingerprint revision
            guard let otherRevision = otherSnapshot.fingerprintRevision,
                  otherRevision == targetRevision,
                  otherSnapshot.fingerprintData != nil,
                  let series = otherSnapshot.series else {
                continue
            }

            seriesSnapshots[series, default: []].append(otherSnapshot)
        }

        // If no series have fingerprints, return nil
        if seriesSnapshots.isEmpty {
            return nil
        }

        // Calculate average distance for each series
        var seriesDistances: [(series: Series, averageDistance: Float)] = []

        for (series, snapshots) in seriesSnapshots {
            var totalDistance: Float = 0
            var validComparisons = 0

            for otherSnapshot in snapshots {
                guard let otherFingerprintData = otherSnapshot.fingerprintData,
                      let distance = FingerprintService.computeDistance(
                        between: targetFingerprintData,
                        and: otherFingerprintData
                      ) else {
                    continue
                }

                totalDistance += distance
                validComparisons += 1
            }

            if validComparisons > 0 {
                let averageDistance = totalDistance / Float(validComparisons)
                seriesDistances.append((series: series, averageDistance: averageDistance))
                #if DEBUG
                log("Series '\(series.name)': avg distance = \(String(format: "%.4f", averageDistance)) (compared against \(validComparisons) snapshots)")
                #endif
            }
        }

        // If no valid comparisons, return nil
        if seriesDistances.isEmpty {
            return nil
        }

        // Sort by distance (closest first)
        seriesDistances.sort { $0.averageDistance < $1.averageDistance }

        // Get the best match
        let bestMatch = seriesDistances[0]

        #if DEBUG
        log("Best match: '\(bestMatch.series.name)' with distance \(String(format: "%.4f", bestMatch.averageDistance)) (threshold: \(String(format: "%.4f", autoAssignmentThreshold)))")
        #endif

        // Only auto-assign if distance is below threshold
        if bestMatch.averageDistance < autoAssignmentThreshold {
            #if DEBUG
            log("✅ Auto-assigning to '\(bestMatch.series.name)' (distance < threshold)")
            #endif
            return bestMatch.series
        }

        #if DEBUG
        log("❌ No auto-assignment (distance >= threshold)")
        #endif

        return nil
    }

    /// Get detailed match results for all series (useful for debugging/logging)
    /// - Parameters:
    ///   - snapshot: The snapshot to match
    ///   - allSnapshots: All snapshots from all series with fingerprints
    /// - Returns: Array of match results for each series, sorted by distance
    static func getDetailedMatchResults(
        for snapshot: ValueSnapshot,
        among allSnapshots: [ValueSnapshot]
    ) -> [MatchResult] {
        guard let targetFingerprintData = snapshot.fingerprintData,
              let targetRevision = snapshot.fingerprintRevision else {
            return []
        }

        // Group snapshots by series
        var seriesSnapshots: [Series: [ValueSnapshot]] = [:]

        for otherSnapshot in allSnapshots {
            if otherSnapshot.id == snapshot.id { continue }

            guard let otherRevision = otherSnapshot.fingerprintRevision,
                  otherRevision == targetRevision,
                  otherSnapshot.fingerprintData != nil,
                  let series = otherSnapshot.series else {
                continue
            }

            seriesSnapshots[series, default: []].append(otherSnapshot)
        }

        // Calculate distances for each series
        var results: [MatchResult] = []

        for (series, snapshots) in seriesSnapshots {
            var totalDistance: Float = 0
            var validComparisons = 0

            for otherSnapshot in snapshots {
                guard let otherFingerprintData = otherSnapshot.fingerprintData,
                      let distance = FingerprintService.computeDistance(
                        between: targetFingerprintData,
                        and: otherFingerprintData
                      ) else {
                    continue
                }

                totalDistance += distance
                validComparisons += 1
            }

            if validComparisons > 0 {
                let averageDistance = totalDistance / Float(validComparisons)
                results.append(MatchResult(
                    series: series,
                    averageDistance: averageDistance,
                    matchedCount: validComparisons
                ))
            }
        }

        // Sort by distance
        results.sort { ($0.averageDistance ?? Float.infinity) < ($1.averageDistance ?? Float.infinity) }

        return results
    }
}
