//
//  VideoPlaybackRepositoryImpl.swift
//  AF Clean
//

import AVFoundation
import Photos

/// Prepares videos for preview.
///
/// Like every other PhotoKit request in the app, network access is off: a
/// preview should never quietly pull a multi-gigabyte original down from
/// iCloud. When only a cloud copy exists we say so instead.
final class VideoPlaybackRepositoryImpl: VideoPlaybackRepository, @unchecked Sendable {

    private let source: PhotoKitDataSource
    private let lock = NSLock()
    private var items: [String: AVPlayerItem] = [:]

    init(source: PhotoKitDataSource) {
        self.source = source
    }

    func playable(for assetID: String) async -> PlayableVideo? {
        guard let asset = source.assets(withIdentifiers: [assetID]).first else { return nil }

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .automatic

        let item: AVPlayerItem? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestPlayerItem(
                forVideo: asset,
                options: options
            ) { item, _ in
                continuation.resume(returning: item)
            }
        }

        guard let item else {
            return PlayableVideo(assetID: assetID, requiresDownload: true)
        }

        lock.withLock { items[assetID] = item }
        return PlayableVideo(assetID: assetID, requiresDownload: false)
    }

    /// Handed to the player by the view layer, keyed by the id in
    /// `PlayableVideo`, so AVFoundation types never appear in the domain.
    func playerItem(for assetID: String) -> AVPlayerItem? {
        lock.withLock { items[assetID] }
    }

    func discard(assetID: String) {
        lock.withLock { _ = items.removeValue(forKey: assetID) }
    }
}
