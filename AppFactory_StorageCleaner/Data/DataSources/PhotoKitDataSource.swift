//
//  PhotoKitDataSource.swift
//  AF Clean
//

import os
import Photos
import UIKit

/// Thin wrapper over PhotoKit: fetching, thumbnails and deletion.
///
/// This is the only type in the app that touches `PHAsset` directly.
final class PhotoKitDataSource: NSObject, @unchecked Sendable {

    private let imageManager = PHCachingImageManager()
    private var changeHandlers: [@Sendable () -> Void] = []
    private let handlerLock = NSLock()
    private var isObserving = false

    /// Identifier to asset, filled in by every fetch.
    ///
    /// Without this, each thumbnail in a grid resolves its own asset with a
    /// separate `fetchAssets(withLocalIdentifiers:)` — hundreds of individual
    /// Photos database queries while scrolling a large library. Every asset the
    /// UI can show has already come through a fetch, so it is already here.
    private var assetsByIdentifier: [String: PHAsset] = [:]
    private let assetLock = NSLock()

    // MARK: - Fetching

    /// Every image that is not a screenshot, oldest first so the scanner's
    /// time-window pass can rely on the ordering.
    func fetchPhotoAssets() -> [PHAsset] {
        fetchImages().filter { !$0.mediaSubtypes.contains(.photoScreenshot) }
    }

    /// Screenshots, newest first — the order a user expects to review them in.
    func fetchScreenshotAssets() -> [PHAsset] {
        #if DEBUG
        if DebugLaunchRoute.treatsPhotosAsScreenshots {
            return Array(fetchImages().reversed())
        }
        #endif
        return fetchImages()
            .filter { $0.mediaSubtypes.contains(.photoScreenshot) }
            .reversed()
    }

    func fetchVideoAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeHiddenAssets = false
        return collect(PHAsset.fetchAssets(with: .video, options: options))
    }

    /// One fetch of all images, split in memory.
    ///
    /// PhotoKit's predicate support for `mediaSubtypes` is unreliable across
    /// versions, so the screenshot split is done here instead — enumerating a
    /// fetch result is cheap because it only touches metadata.
    private func fetchImages() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.includeHiddenAssets = false
        return collect(PHAsset.fetchAssets(with: .image, options: options))
    }

    private func collect(_ result: PHFetchResult<PHAsset>) -> [PHAsset] {
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        remember(assets)
        return assets
    }

    private func remember(_ assets: [PHAsset]) {
        guard !assets.isEmpty else { return }
        assetLock.lock()
        for asset in assets {
            assetsByIdentifier[asset.localIdentifier] = asset
        }
        assetLock.unlock()
    }

    /// Resolves identifiers, preferring the memo and only querying PhotoKit for
    /// whatever is genuinely unknown.
    func assets(withIdentifiers ids: [String]) -> [PHAsset] {
        guard !ids.isEmpty else { return [] }

        assetLock.lock()
        var found: [PHAsset] = []
        var missing: [String] = []
        for id in ids {
            if let asset = assetsByIdentifier[id] {
                found.append(asset)
            } else {
                missing.append(id)
            }
        }
        assetLock.unlock()

        guard !missing.isEmpty else { return found }

        let fetched = collect(PHAsset.fetchAssets(withLocalIdentifiers: missing, options: nil))
        return found + fetched
    }

    /// Drops assets the app has deleted, so the memo cannot hand back a stale
    /// object after a clean-up.
    func forget(identifiers: [String]) {
        assetLock.lock()
        for id in identifiers { assetsByIdentifier.removeValue(forKey: id) }
        assetLock.unlock()
    }

    // MARK: - Images

    /// Requests a thumbnail.
    ///
    /// Network access is allowed here, and that is a deliberate correctness
    /// decision rather than an oversight. When "Optimise iPhone Storage" is on —
    /// which is the default — most of the library exists locally only as a
    /// placeholder, and every request with networking disabled fails with
    /// `PHPhotosError.networkAccessRequired` (3303). Turning it off would mean
    /// the scan silently found nothing for exactly the users who most need to
    /// free up space.
    ///
    /// This does not conflict with keeping the user's data on device: nothing
    /// is uploaded or sent anywhere. We only ask iCloud for a small rendition
    /// of the user's own photo, sized to `maxPixel` — a few kilobytes for the
    /// 64px thumbnails the hash pass uses, never the full original.
    ///
    /// Video playback is the exception and passes `allowsNetwork: false`, since
    /// previewing must not pull down a multi-gigabyte original.
    func image(
        for asset: PHAsset,
        maxPixel: Int,
        allowsNetwork: Bool = true
    ) async -> CGImage? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = allowsNetwork
        options.isSynchronous = false
        // Downsampling quality is irrelevant at these sizes, and `.fast` is
        // what keeps a full-library pass cheap.
        options.resizeMode = .fast
        // `.highQualityFormat` rather than `.fastFormat`, even for hashing.
        //
        // `.fastFormat` only ever returns an *already cached* rendition. On a
        // library PhotoKit has not built thumbnails for, it returns no image at
        // all and reports PHPhotosError.networkAccessRequired (3303) — even
        // when the original is sitting locally on disk. Using it made the scan
        // find nothing on a fresh install. `.highQualityFormat` decodes and
        // downsamples on demand, and still serves from the thumbnail cache when
        // one exists. `.opportunistic` is avoided because it calls back
        // repeatedly, which makes single-resume continuation handling fragile.
        options.deliveryMode = .highQualityFormat

        let target = CGSize(width: maxPixel, height: maxPixel)

        return await withCheckedContinuation { continuation in
            let hasResumed = ResumeGuard()
            imageManager.requestImage(
                for: asset,
                targetSize: target,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // Resume on the first callback whatever it contains. The
                // delivery modes above only ever produce one, so waiting for a
                // "better" result would simply hang the task forever.
                guard hasResumed.claim() else { return }
                if image == nil, let error = info?[PHImageErrorKey] as? NSError {
                    AFLog.scan.error("thumbnail failed: \(error.domain) \(error.code)")
                }
                continuation.resume(returning: image?.cgImage)
            }
        }
    }

    func startCaching(_ assets: [PHAsset], maxPixel: Int) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        imageManager.startCachingImages(
            for: assets,
            targetSize: CGSize(width: maxPixel, height: maxPixel),
            contentMode: .aspectFill,
            options: options
        )
    }

    func stopCaching(_ assets: [PHAsset], maxPixel: Int) {
        imageManager.stopCachingImages(
            for: assets,
            targetSize: CGSize(width: maxPixel, height: maxPixel),
            contentMode: .aspectFill,
            options: nil
        )
    }

    func stopCachingAll() {
        imageManager.stopCachingImagesForAllAssets()
    }

    // MARK: - Deletion

    /// Deletes via the photo library, which shows iOS's own confirmation sheet.
    /// - Returns: the identifiers that were actually removed.
    func delete(_ assets: [PHAsset]) async throws -> [String] {
        guard !assets.isEmpty else { return [] }
        let identifiers = assets.map(\.localIdentifier)

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
            forget(identifiers: identifiers)
            return identifiers
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(_ error: Error) -> PhotoDeletionError {
        let nsError = error as NSError
        // The user tapping "Don't Allow" on iOS's sheet is not a failure —
        // it is the safety net working.
        if nsError.domain == PHPhotosErrorDomain,
           nsError.code == PHPhotosError.userCancelled.rawValue {
            return .cancelledByUser
        }
        if nsError.domain == PHPhotosErrorDomain,
           nsError.code == PHPhotosError.accessRestricted.rawValue
            || nsError.code == PHPhotosError.accessUserDenied.rawValue {
            return .notAuthorised
        }
        return .failed(error.localizedDescription)
    }

    // MARK: - Change observation

    func addChangeHandler(_ handler: @escaping @Sendable () -> Void) {
        handlerLock.lock()
        changeHandlers.append(handler)
        let shouldRegister = !isObserving
        isObserving = true
        handlerLock.unlock()

        if shouldRegister {
            PHPhotoLibrary.shared().register(self)
        }
    }
}

extension PhotoKitDataSource: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        handlerLock.lock()
        let handlers = changeHandlers
        handlerLock.unlock()
        handlers.forEach { $0() }
    }
}

/// Ensures a `CheckedContinuation` fed by a multi-callback API is resumed once.
private final class ResumeGuard: @unchecked Sendable {
    private var claimed = false
    private let lock = NSLock()

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !claimed else { return false }
        claimed = true
        return true
    }
}
