//
//  MediaAsset.swift
//  AF Clean
//
//  Framework-free description of one item in the photo library. The Data layer
//  maps PHAsset into this at the boundary so nothing above it imports PhotoKit.
//

import Foundation

struct MediaAsset: Identifiable, Hashable, Sendable {

    enum Kind: String, Sendable {
        case photo
        case screenshot
        case video
    }

    /// `PHAsset.localIdentifier`.
    let id: String
    let kind: Kind
    /// Best available byte size. Never zero — see `AssetSizeResolver`.
    let byteSize: Int64
    let pixelWidth: Int
    let pixelHeight: Int
    let creationDate: Date?
    let modificationDate: Date?
    /// Zero for stills.
    let duration: TimeInterval
    let isFavorite: Bool
    /// The user has edited this one, which makes it a better keep candidate.
    let hasAdjustments: Bool

    var pixelCount: Int { pixelWidth * pixelHeight }

    var megapixels: Double { Double(pixelCount) / 1_000_000 }

    var aspectRatio: Double {
        pixelHeight > 0 ? Double(pixelWidth) / Double(pixelHeight) : 1
    }

    var isVideo: Bool { kind == .video }
}

extension Array where Element == MediaAsset {
    var totalBytes: Int64 { reduce(0) { $0 + $1.byteSize } }
}
