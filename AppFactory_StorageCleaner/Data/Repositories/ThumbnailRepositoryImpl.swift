//
//  ThumbnailRepositoryImpl.swift
//  AF Clean
//

import CoreGraphics
import Photos

struct ThumbnailRepositoryImpl: ThumbnailRepository {

    private let source: PhotoKitDataSource

    init(source: PhotoKitDataSource) {
        self.source = source
    }

    func thumbnail(for assetID: String, maxPixel: Int) async -> CGImage? {
        guard let asset = source.assets(withIdentifiers: [assetID]).first else { return nil }
        return await source.image(for: asset, maxPixel: maxPixel, fast: false)
    }

    func startCaching(assetIDs: [String], maxPixel: Int) {
        let assets = source.assets(withIdentifiers: assetIDs)
        guard !assets.isEmpty else { return }
        source.startCaching(assets, maxPixel: maxPixel)
    }

    func stopCaching(assetIDs: [String], maxPixel: Int) {
        let assets = source.assets(withIdentifiers: assetIDs)
        guard !assets.isEmpty else { return }
        source.stopCaching(assets, maxPixel: maxPixel)
    }

    func stopCachingAll() {
        source.stopCachingAll()
    }
}
