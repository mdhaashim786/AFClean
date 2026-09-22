//
//  PhotoAssetRepository.swift
//  AF Clean
//

import Foundation

enum PhotoDeletionError: Error, Equatable {
    /// The user backed out at iOS's own confirmation sheet. Not a failure —
    /// the safety net doing its job.
    case cancelledByUser
    case notAuthorised
    case failed(String)
}

protocol PhotoAssetRepository: Sendable {

    /// Camera-roll photos, excluding screenshots (those are their own category).
    func fetchPhotos() async -> [MediaAsset]

    func fetchScreenshots() async -> [MediaAsset]

    /// Videos, largest first.
    func fetchVideos() async -> [MediaAsset]

    /// Deletes assets via the photo library. iOS presents its own confirmation
    /// sheet, so this is the second gate after our review screen.
    /// - Returns: the assets that were actually removed.
    func deleteAssets(ids: [String]) async throws -> [String]

    /// Fires whenever the photo library changes underneath us, so cached scan
    /// results can be marked stale instead of silently going wrong.
    func observeLibraryChanges(_ onChange: @escaping @Sendable () -> Void)
}
