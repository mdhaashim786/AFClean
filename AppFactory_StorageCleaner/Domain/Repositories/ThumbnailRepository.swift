//
//  ThumbnailRepository.swift
//  AF Clean
//

import CoreGraphics

/// Supplies preview images by asset id.
///
/// Returns `CGImage` rather than `UIImage` or `Data`: it keeps PhotoKit and
/// UIKit out of the layers above without paying to re-encode every thumbnail.
protocol ThumbnailRepository: Sendable {

    func thumbnail(for assetID: String, maxPixel: Int) async -> CGImage?

    /// Warms the cache for rows about to scroll into view.
    func startCaching(assetIDs: [String], maxPixel: Int)
    func stopCaching(assetIDs: [String], maxPixel: Int)
    func stopCachingAll()
}
