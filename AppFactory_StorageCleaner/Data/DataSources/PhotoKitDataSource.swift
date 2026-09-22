//
//  PhotoKitDataSource.swift
//  AF Clean
//

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

    // MARK: - Fetching

    /// Every image that is not a screenshot, oldest first so the scanner's
    /// time-window pass can rely on the ordering.
    func fetchPhotoAssets() -> [PHAsset] {
        fetchImages().filter { !$0.mediaSubtypes.contains(.photoScreenshot) }
    }

    /// Screenshots, newest first — the order a user expects to review them in.
    func fetchScreenshotAssets() -> [PHAsset] {
        fetchImages()
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
        return assets
    }

    func assets(withIdentifiers ids: [String]) -> [PHAsset] {
        guard !ids.isEmpty else { return [] }
        return collect(PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil))
    }

    // MARK: - Images

    /// Requests a thumbnail.
    ///
    /// `isNetworkAccessAllowed` is deliberately off everywhere: the brief says
    /// everything runs on device, and letting PhotoKit silently pull originals
    /// from iCloud would make a large scan both slow and expensive.
    func image(for asset: PHAsset, maxPixel: Int, fast: Bool) async -> CGImage? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false
        options.resizeMode = .fast
        // .fastFormat calls back exactly once, which is what the hashing pass
        // wants; display can afford to wait for the better rendition.
        options.deliveryMode = fast ? .fastFormat : .highQualityFormat

        let target = CGSize(width: maxPixel, height: maxPixel)

        return await withCheckedContinuation { continuation in
            let hasResumed = ResumeGuard()
            imageManager.requestImage(
                for: asset,
                targetSize: target,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // Opportunistic delivery can call back more than once; only the
                // first non-degraded result should resume the continuation.
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded || image == nil else { return }
                guard hasResumed.claim() else { return }
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
