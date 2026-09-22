//
//  FetchLargeVideosUseCase.swift
//  AF Clean
//

import Foundation

/// Videos, largest first — the brief's ordering.
struct FetchLargeVideosUseCase: Sendable {
    private let photos: PhotoAssetRepository

    init(photos: PhotoAssetRepository) {
        self.photos = photos
    }

    func callAsFunction() async -> [MediaAsset] {
        await photos.fetchVideos().sorted { $0.byteSize > $1.byteSize }
    }
}
