//
//  ImageHashRepositoryImpl.swift
//  AF Clean
//

import Photos

/// Computes perceptual hashes for the similarity scan.
///
/// Speed on a large library comes from three things:
///   - a persistent cache, so only new or edited assets are ever analysed;
///   - tiny 64px thumbnails requested in `.fastFormat`, which PhotoKit can
///     usually serve straight from its own thumbnail store;
///   - a bounded concurrency window, so the work saturates the device without
///     asking PhotoKit for thousands of images at once.
struct ImageHashRepositoryImpl: ImageHashRepository {

    /// Big enough for a stable 9x8 downsample, small enough that PhotoKit
    /// almost always has it cached already.
    private static let hashThumbnailPixels = 64
    /// Feature prints need real detail to be meaningful.
    private static let featureThumbnailPixels = 224

    private let source: PhotoKitDataSource
    private let cache: AssetAnalysisCache
    private let concurrency: Int

    init(source: PhotoKitDataSource, cache: AssetAnalysisCache, concurrency: Int = 8) {
        self.source = source
        self.cache = cache
        self.concurrency = concurrency
    }

    func hashes(
        for assets: [MediaAsset],
        onProgress: @Sendable @escaping (Int, Int, Int) -> Void
    ) async -> [String: UInt64] {

        guard !assets.isEmpty else { return [:] }

        var result: [String: UInt64] = [:]
        result.reserveCapacity(assets.count)

        // Split cached from uncached first so progress reflects real work and
        // a repeat scan finishes almost immediately.
        var toAnalyse: [MediaAsset] = []
        for asset in assets {
            if let entry = cache.entry(for: asset.id, modifiedAt: asset.modificationDate), entry.hash != 0 {
                result[asset.id] = entry.hash
            } else {
                toAnalyse.append(asset)
            }
        }

        let total = assets.count
        let cacheHits = result.count
        var processed = cacheHits
        onProgress(processed, total, cacheHits)

        guard !toAnalyse.isEmpty else {
            cache.persist()
            return result
        }

        // Resolve identifiers to PHAssets once, in bulk.
        let assetsByID = Dictionary(
            source.assets(withIdentifiers: toAnalyse.map(\.id))
                .map { ($0.localIdentifier, AssetBox($0)) },
            uniquingKeysWith: { first, _ in first }
        )

        let source = self.source
        let pixels = Self.hashThumbnailPixels

        await concurrentForEach(
            toAnalyse,
            limit: concurrency,
            transform: { media -> (String, UInt64, MediaAsset)? in
                guard let box = assetsByID[media.id] else { return nil }
                guard let image = await source.image(for: box.value, maxPixel: pixels),
                      let hash = DifferenceHasher.hash(of: image)
                else { return nil }
                return (media.id, hash, media)
            },
            onResult: { id, hash, media in
                result[id] = hash
                cache.store(
                    AssetAnalysisCache.Entry(
                        hash: hash,
                        byteSize: media.byteSize,
                        hasAdjustments: media.hasAdjustments,
                        modifiedAt: media.modificationDate?.timeIntervalSince1970 ?? 0
                    ),
                    for: id
                )
                processed += 1
                onProgress(processed, total, cacheHits)
            }
        )

        // Deliberately no pruning here: this pass only knows about photos, so
        // pruning to its id set would evict every screenshot and video entry.
        // The cache bounds itself on load instead.
        cache.persist()
        return result
    }

    // MARK: - Verification

    func featureDistance(between lhs: String, and rhs: String) async -> Float? {
        let assets = source.assets(withIdentifiers: [lhs, rhs])
        guard assets.count == 2 else { return nil }

        // Keep the requested order; fetchAssets does not guarantee it.
        guard let left = assets.first(where: { $0.localIdentifier == lhs }),
              let right = assets.first(where: { $0.localIdentifier == rhs })
        else { return nil }

        let pixels = Self.featureThumbnailPixels
        guard let leftImage = await source.image(for: left, maxPixel: pixels),
              let rightImage = await source.image(for: right, maxPixel: pixels),
              let leftPrint = FeaturePrintComparator.featurePrint(for: leftImage),
              let rightPrint = FeaturePrintComparator.featurePrint(for: rightImage)
        else { return nil }

        return FeaturePrintComparator.distance(leftPrint, rightPrint)
    }
}
