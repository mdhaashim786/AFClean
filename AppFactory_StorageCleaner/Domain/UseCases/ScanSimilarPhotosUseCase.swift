//
//  ScanSimilarPhotosUseCase.swift
//  AF Clean
//

import Foundation

/// Fetch photos, fingerprint them, group the matches, then verify the weakest
/// groups before showing them.
///
/// Emits progress throughout so the UI can stay honest about a scan that may
/// take a while the first time it runs.
struct ScanSimilarPhotosUseCase: Sendable {

    private let photos: PhotoAssetRepository
    private let hashes: ImageHashRepository
    private let grouper: SimilarityGrouper
    private let verificationThreshold: Float

    init(
        photos: PhotoAssetRepository,
        hashes: ImageHashRepository,
        grouper: SimilarityGrouper = SimilarityGrouper(),
        verificationThreshold: Float = 0.6
    ) {
        self.photos = photos
        self.hashes = hashes
        self.grouper = grouper
        self.verificationThreshold = verificationThreshold
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
        let verified = await verify(groups)

        onProgress(
            ScanProgress(
                phase: .finished,
                processed: assets.count,
                total: assets.count,
                elapsed: Date().timeIntervalSince(started)
            )
        )
        return verified
    }

    // MARK: - Verification

    /// Re-checks `.similar` groups with Vision.
    ///
    /// Those are the ones held together only by a loose hash match between
    /// photos taken at unrelated times — by far the likeliest place for a false
    /// positive, and the most annoying place to have one, since the user could
    /// delete a photo that is not actually a duplicate.
    ///
    /// Exact duplicates and bursts are left alone: they are already reliable,
    /// and they are the bulk of the results, so skipping them keeps this cheap.
    /// If Vision cannot answer, the member is kept — we never drop a result on
    /// the strength of a failed check.
    private func verify(_ groups: [PhotoGroup]) async -> [PhotoGroup] {
        var verified: [PhotoGroup] = []
        verified.reserveCapacity(groups.count)

        for group in groups {
            guard group.reason == .similar else {
                verified.append(group)
                continue
            }
            guard !Task.isCancelled else { return verified + groups[verified.count...] }

            let best = group.best
            var kept: [MediaAsset] = [best]

            for candidate in group.others {
                let distance = await hashes.featureDistance(between: best.id, and: candidate.id)
                if let distance, distance > verificationThreshold { continue }
                kept.append(candidate)
            }

            guard kept.count > 1 else { continue }

            verified.append(
                PhotoGroup(
                    id: group.id,
                    assets: group.assets.filter { asset in kept.contains(where: { $0.id == asset.id }) },
                    bestAssetID: best.id,
                    reason: group.reason
                )
            )
        }

        return verified
    }
}
