//
//  ScanSimilarPhotosUseCase.swift
//  AF Clean
//

import Foundation

/// Fetch photos, fingerprint them, group the matches.
///
/// Emits progress as it goes so the UI can stay honest about a scan that may
/// take a while on first run.
struct ScanSimilarPhotosUseCase: Sendable {

    private let photos: PhotoAssetRepository
    private let hashes: ImageHashRepository
    private let grouper: SimilarityGrouper

    init(
        photos: PhotoAssetRepository,
        hashes: ImageHashRepository,
        grouper: SimilarityGrouper = SimilarityGrouper()
    ) {
        self.photos = photos
        self.hashes = hashes
        self.grouper = grouper
    }

    func callAsFunction(
        onProgress: @Sendable @escaping (ScanProgress) -> Void
    ) async -> [PhotoGroup] {
        let started = Date()
        onProgress(ScanProgress(phase: .fetching))

        let assets = await photos.fetchPhotos()
        guard !Task.isCancelled else { return [] }
        guard assets.count > 1 else {
            onProgress(ScanProgress(phase: .finished, elapsed: Date().timeIntervalSince(started)))
            return []
        }

        onProgress(ScanProgress(phase: .analysing, total: assets.count))

        let fingerprints = await hashes.hashes(for: assets) { processed, total, cacheHits in
            onProgress(
                ScanProgress(
                    phase: .analysing,
                    processed: processed,
                    total: total,
                    elapsed: Date().timeIntervalSince(started),
                    cacheHits: cacheHits
                )
            )
        }
        guard !Task.isCancelled else { return [] }

        onProgress(
            ScanProgress(
                phase: .grouping,
                processed: assets.count,
                total: assets.count,
                elapsed: Date().timeIntervalSince(started)
            )
        )

        let groups = grouper.group(assets: assets, hashes: fingerprints)

        onProgress(
            ScanProgress(
                phase: .finished,
                processed: assets.count,
                total: assets.count,
                elapsed: Date().timeIntervalSince(started)
            )
        )
        return groups
    }
}
