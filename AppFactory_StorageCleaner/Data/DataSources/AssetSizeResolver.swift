//
//  AssetSizeResolver.swift
//  AF Clean
//

import Photos

/// Works out how many bytes an asset actually occupies.
///
/// PhotoKit has no public API for this. The accepted approach is the
/// undocumented `fileSize` key on `PHAssetResource`, so every lookup here is
/// wrapped: if the key ever stops answering, we fall back to an estimate from
/// the asset's own metadata rather than reporting zero and telling the user a
/// deletion frees nothing.
enum AssetSizeResolver {

    struct Result: Sendable {
        let byteSize: Int64
        /// The user has edited this asset, which makes it a better keep.
        let hasAdjustments: Bool
    }

    static func resolve(_ asset: PHAsset) -> Result {
        let resources = PHAssetResource.assetResources(for: asset)

        // Sum every resource: an edited photo keeps its original alongside the
        // edit, and a Live Photo keeps its paired video. Deleting the asset
        // frees all of them, so that is what we should be counting.
        var total: Int64 = 0
        var hasAdjustments = false

        for resource in resources {
            if let size = fileSize(of: resource) {
                total += size
            }
            if resource.type == .adjustmentData || resource.type == .fullSizePhoto
                || resource.type == .fullSizeVideo {
                hasAdjustments = true
            }
        }

        return Result(
            byteSize: total > 0 ? total : estimate(for: asset),
            hasAdjustments: hasAdjustments
        )
    }

    private static func fileSize(of resource: PHAssetResource) -> Int64? {
        // Undocumented but long-standing. Typed loosely because it has been
        // seen as both NSNumber-backed Int64 and Int.
        guard let value = resource.value(forKey: "fileSize") else { return nil }
        if let number = value as? NSNumber {
            let size = number.int64Value
            return size > 0 ? size : nil
        }
        if let size = value as? Int64, size > 0 { return size }
        if let size = value as? Int, size > 0 { return Int64(size) }
        return nil
    }

    /// Last-resort approximation from pixel count or duration.
    ///
    /// Deliberately conservative — it is better to under-promise the space a
    /// clean-up will free than to over-promise it.
    static func estimate(for asset: PHAsset) -> Int64 {
        let pixels = Int64(asset.pixelWidth) * Int64(asset.pixelHeight)

        switch asset.mediaType {
        case .video:
            // Rough HEVC bitrate scaled by resolution, ~1080p as the baseline.
            let baseline: Double = 2_000_000 / 8   // bytes per second at 1080p
            let scale = max(0.25, Double(pixels) / (1920.0 * 1080.0))
            let seconds = max(asset.duration, 1)
            return Int64(baseline * scale * seconds)
        default:
            // HEIC lands around a quarter of a byte per pixel.
            return max(Int64(Double(pixels) * 0.25), 80_000)
        }
    }
}
