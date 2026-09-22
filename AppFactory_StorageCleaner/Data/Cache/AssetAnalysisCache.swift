//
//  AssetAnalysisCache.swift
//  AF Clean
//

import Foundation
import os

/// Remembers the expensive per-asset facts — perceptual hash and byte size —
/// between runs.
///
/// This is what makes the second scan of a large library near-instant: only
/// assets that are new or have been edited since we last looked need any work.
/// Entries are validated against the asset's modification date, so an edited
/// photo is correctly re-analysed rather than served stale.
final class AssetAnalysisCache: @unchecked Sendable {

    struct Entry: Codable, Sendable {
        let hash: UInt64
        let byteSize: Int64
        let hasAdjustments: Bool
        /// `PHAsset.modificationDate`, used to detect staleness.
        let modifiedAt: TimeInterval
    }

    private let fileURL: URL
    private let lock = OSAllocatedUnfairLock<[String: Entry]>(initialState: [:])
    private var isDirty = false
    private let dirtyLock = NSLock()

    init(filename: String = "asset-analysis.cache") {
        let directory = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())

        self.fileURL = directory.appendingPathComponent(filename)
        load()
    }

    // MARK: - Access

    /// Returns the cached entry only if it still matches the asset's
    /// modification date.
    func entry(for id: String, modifiedAt: Date?) -> Entry? {
        guard let entry = lock.withLock({ $0[id] }) else { return nil }
        let current = modifiedAt?.timeIntervalSince1970 ?? 0
        // Sub-second differences are noise from date round-tripping.
        guard abs(entry.modifiedAt - current) < 1 else { return nil }
        return entry
    }

    func store(_ entry: Entry, for id: String) {
        lock.withLock { $0[id] = entry }
        dirtyLock.withLock { isDirty = true }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? PropertyListDecoder().decode([String: Entry].self, from: data)
        else { return }
        guard decoded.count <= Self.maximumEntries else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        lock.withLock { $0 = decoded }
    }

    /// Writes the cache out if anything changed. Cheap enough to call at the
    /// end of every scan.
    func persist() {
        let shouldWrite = dirtyLock.withLock { () -> Bool in
            defer { isDirty = false }
            return isDirty
        }
        guard shouldWrite else { return }

        let snapshot = lock.withLock { $0 }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Upper bound on retained entries.
    ///
    /// Entries are keyed by asset identifier and are never removed when an
    /// asset is deleted, so over a long life the file would otherwise only
    /// grow. Rather than track deletions, the cache simply resets itself once
    /// it is clearly larger than any real library — it is a cache, so the only
    /// cost of being wrong is one slower scan.
    private static let maximumEntries = 200_000
}
