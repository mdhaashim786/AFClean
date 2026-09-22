//
//  PhotoGroup.swift
//  AF Clean
//

import Foundation

/// A set of photos the scanner considers duplicates or near-identical shots.
///
/// Exactly one member is the `best` one and is never pre-selected for deletion;
/// the brief asks us to mark the best shot and let the user select the rest.
struct PhotoGroup: Identifiable, Hashable, Sendable {

    enum Reason: String, Sendable {
        /// Byte-for-byte or pixel-identical copies.
        case exactDuplicate
        /// Shot seconds apart — bursts, retries of the same frame.
        case burst
        /// Visually similar but not taken together.
        case similar

        var title: String {
            switch self {
            case .exactDuplicate: "Duplicates"
            case .burst: "Taken together"
            case .similar: "Similar shots"
            }
        }
    }

    let id: String
    /// Every member, oldest first. Always contains at least two assets.
    let assets: [MediaAsset]
    let bestAssetID: String
    let reason: Reason

    var best: MediaAsset {
        assets.first { $0.id == bestAssetID } ?? assets[0]
    }

    /// Everything except the keeper — what the user is invited to remove.
    var others: [MediaAsset] {
        assets.filter { $0.id != bestAssetID }
    }

    /// Space recovered if the user removes everything but the keeper.
    var reclaimableBytes: Int64 { others.totalBytes }

    var count: Int { assets.count }
}

extension Array where Element == PhotoGroup {
    var totalReclaimableBytes: Int64 { reduce(0) { $0 + $1.reclaimableBytes } }
    var totalRemovableCount: Int { reduce(0) { $0 + $1.others.count } }
}
