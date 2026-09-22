//
//  PhotoAssetRepositoryImpl.swift
//  AF Clean
//

import Photos

/// Fetches assets and resolves their sizes.
///
/// Size resolution is the expensive half: PhotoKit only answers it per-asset,
/// so a large library would spend seconds on it. It is therefore run
/// concurrently over a bounded window and memoised in `AssetAnalysisCache`,
/// keyed by modification date, making every scan after the first nearly free.
struct PhotoAssetRepositoryImpl: PhotoAssetRepository {

    private let source: PhotoKitDataSource
    private let cache: AssetAnalysisCache
    private let concurrency: Int

    init(source: PhotoKitDataSource, cache: AssetAnalysisCache, concurrency: Int = 8) {
        self.source = source
        self.cache = cache
        self.concurrency = concurrency
    }

    // MARK: - Fetching

    func fetchPhotos() async -> [MediaAsset] {
        await map(source.fetchPhotoAssets())
    }

    func fetchScreenshots() async -> [MediaAsset] {
        await map(source.fetchScreenshotAssets())
    }

    func fetchVideos() async -> [MediaAsset] {
        await map(source.fetchVideoAssets())
    }

    private func map(_ assets: [PHAsset]) async -> [MediaAsset] {
        guard !assets.isEmpty else { return [] }

        // Anything already cached needs no PhotoKit round trip at all.
        var results = [MediaAsset?](repeating: nil, count: assets.count)
        var pending: [(index: Int, asset: AssetBox)] = []

        for (index, asset) in assets.enumerated() {
            if let entry = cache.entry(for: asset.localIdentifier, modifiedAt: asset.modificationDate) {
                results[index] = PHAssetMapper.map(
                    asset,
                    size: .init(byteSize: entry.byteSize, hasAdjustments: entry.hasAdjustments)
                )
            } else {
                pending.append((index, AssetBox(asset)))
            }
        }

        if !pending.isEmpty {
            await concurrentForEach(
                pending,
                limit: concurrency,
                transform: { item -> (Int, MediaAsset, AssetAnalysisCache.Entry)? in
                    let asset = item.asset.value
                    let size = AssetSizeResolver.resolve(asset)
                    let media = PHAssetMapper.map(asset, size: size)
                    // Hash is filled in later by the analysis pass; zero is a
                    // placeholder that `entry(for:)` callers treat as absent.
                    let entry = AssetAnalysisCache.Entry(
                        hash: 0,
                        byteSize: size.byteSize,
                        hasAdjustments: size.hasAdjustments,
                        modifiedAt: asset.modificationDate?.timeIntervalSince1970 ?? 0
                    )
                    return (item.index, media, entry)
                },
                onResult: { index, media, entry in
                    results[index] = media
                    cache.store(entry, for: media.id)
                }
            )
            cache.persist()
        }

        return results.compactMap { $0 }
    }

    // MARK: - Deletion

    func deleteAssets(ids: [String]) async throws -> [String] {
        let assets = source.assets(withIdentifiers: ids)
        guard !assets.isEmpty else { return [] }
        return try await source.delete(assets)
    }

    // MARK: - Change observation

    func observeLibraryChanges(_ onChange: @escaping @Sendable () -> Void) {
        source.addChangeHandler(onChange)
    }
}

/// `PHAsset` is a thread-safe immutable snapshot but is not marked `Sendable`,
/// so it needs an explicit box to cross into a task group.
struct AssetBox: @unchecked Sendable {
    let value: PHAsset
    init(_ value: PHAsset) { self.value = value }
}
