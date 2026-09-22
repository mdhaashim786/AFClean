//
//  PHAssetMapper.swift
//  AF Clean
//

import Photos

/// Converts `PHAsset` into the domain's `MediaAsset`.
///
/// This is the boundary: above it, nothing knows PhotoKit exists.
enum PHAssetMapper {

    static func map(_ asset: PHAsset, size: AssetSizeResolver.Result) -> MediaAsset {
        MediaAsset(
            id: asset.localIdentifier,
            kind: kind(of: asset),
            byteSize: size.byteSize,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            creationDate: asset.creationDate,
            modificationDate: asset.modificationDate,
            duration: asset.mediaType == .video ? asset.duration : 0,
            isFavorite: asset.isFavorite,
            hasAdjustments: size.hasAdjustments
        )
    }

    static func kind(of asset: PHAsset) -> MediaAsset.Kind {
        if asset.mediaType == .video { return .video }
        return asset.mediaSubtypes.contains(.photoScreenshot) ? .screenshot : .photo
    }
}
