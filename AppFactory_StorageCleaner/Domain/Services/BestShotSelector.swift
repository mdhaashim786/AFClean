//
//  BestShotSelector.swift
//  AF Clean
//

import Foundation

/// Picks the one photo to keep out of a group of near-identical shots.
///
/// The brief asks us to "mark the best one in each group and let the user
/// select the rest", so this decides what gets the Best badge and, by
/// implication, what is pre-selected for deletion.
struct BestShotSelector {

    struct Weights {
        /// A favourite is an explicit signal from the user. It should beat
        /// every automatic signal we have.
        var favourite: Double = 10_000
        /// An edited photo is one the user cared enough to work on.
        var edited: Double = 2_000
        var perMegapixel: Double = 120
        /// More bytes at the same resolution means less compression.
        var perMegabyte: Double = 8
        /// Breaks ties towards the newest shot — usually the keeper in a burst.
        var recency: Double = 0.000_01

        static let `default` = Weights()
    }

    let weights: Weights

    init(weights: Weights = .default) {
        self.weights = weights
    }

    func score(_ asset: MediaAsset) -> Double {
        var total = 0.0
        if asset.isFavorite { total += weights.favourite }
        if asset.hasAdjustments { total += weights.edited }
        total += asset.megapixels * weights.perMegapixel
        total += Double(asset.byteSize) / 1_048_576 * weights.perMegabyte
        if let date = asset.creationDate {
            total += date.timeIntervalSince1970 * weights.recency
        }
        return total
    }

    func best(in assets: [MediaAsset]) -> MediaAsset? {
        assets.max { lhs, rhs in
            let left = score(lhs)
            let right = score(rhs)
            // Stable tiebreak on id so the badge never moves between scans.
            return left == right ? lhs.id < rhs.id : left < right
        }
    }
}
