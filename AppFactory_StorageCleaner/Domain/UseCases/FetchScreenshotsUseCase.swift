//
//  FetchScreenshotsUseCase.swift
//  AF Clean
//

import Foundation

/// Screenshots need no analysis — the photo library already tags them — so this
/// is a straight fetch, newest first.
struct FetchScreenshotsUseCase: Sendable {
    private let photos: PhotoAssetRepository

    init(photos: PhotoAssetRepository) {
        self.photos = photos
    }

    func callAsFunction() async -> [MediaAsset] {
        await photos.fetchScreenshots()
    }
}
