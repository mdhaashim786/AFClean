//
//  SimilarityGrouper.swift
//  AF Clean
//

import Foundation

/// Turns per-photo perceptual hashes into groups of duplicates and
/// near-identical shots.
///
/// Performance is the whole design here. A naive scan compares every photo to
/// every other one, which is 200 million comparisons on a 20,000-photo library.
/// Instead this runs three cheap passes, each of which only ever looks at
/// plausible candidates:
///
///   1. **Exact hash classes** — a dictionary lookup, O(n). Collapses identical
///      copies (and the huge same-hash clusters that flat images produce) into
///      one representative before anything more expensive runs.
///   2. **Time window** — bursts and retries are seconds apart, so a sliding
///      window over date-sorted photos catches them in O(n·w).
///   3. **LSH banding** — for look-alikes taken far apart, bucket the hash
///      bands and only compare within a bucket.
///
/// Every proposed match is fed to a union-find, which collapses them into final
/// groups.
struct SimilarityGrouper {

    struct Configuration {
        /// Bits that may differ for two photos taken moments apart to count as
        /// the same shot. Generous: a burst re-frames slightly between frames.
        var burstDistance: Int = 8
        /// Stricter threshold for photos taken at unrelated times, where a
        /// loose match is far more likely to be a false positive.
        var similarDistance: Int = 4
        /// How far apart two photos can be and still be treated as one burst.
        var burstWindow: TimeInterval = 60
        /// How many photos ahead the time-window pass looks. Caps the cost of a
        /// single second containing thousands of imported photos.
        var windowLookahead: Int = 40
        var bandCount: Int = 4
        /// Buckets bigger than this are flat/low-detail images (blank pages,
        /// solid backgrounds) that would otherwise pull unrelated photos
        /// together. Skipped rather than trusted.
        var maximumBucketSize: Int = 64

        static let `default` = Configuration()
    }

    let configuration: Configuration
    let selector: BestShotSelector

    init(
        configuration: Configuration = .default,
        selector: BestShotSelector = BestShotSelector()
    ) {
        self.configuration = configuration
        self.selector = selector
    }

    // MARK: - Entry point

    /// - Parameters:
    ///   - assets: candidates, in any order.
    ///   - hashes: perceptual hash per asset id. Assets without one are ignored.
    /// - Returns: groups of two or more, largest reclaimable saving first.
    func group(assets: [MediaAsset], hashes: [String: UInt64]) -> [PhotoGroup] {
        // Only assets we could fingerprint can take part, sorted by date so the
        // time-window pass can rely on ordering.
        let items = assets
            .compactMap { asset -> (asset: MediaAsset, hash: UInt64)? in
                guard let hash = hashes[asset.id] else { return nil }
                return (asset, hash)
            }
            .sorted { lhs, rhs in
                let left = lhs.asset.creationDate ?? .distantPast
                let right = rhs.asset.creationDate ?? .distantPast
                return left == right ? lhs.asset.id < rhs.asset.id : left < right
            }

        guard items.count > 1 else { return [] }

        var sets = UnionFind(count: items.count)
        // Tracks why each element got joined, so the group can be labelled.
        var exactPairs = Set<Int>()
        var burstPairs = Set<Int>()

        let representatives = unionExactDuplicates(items, into: &sets, exact: &exactPairs)
        unionBursts(items, into: &sets, burst: &burstPairs)
        unionLookalikes(items, representatives: representatives, into: &sets)

        return buildGroups(
            items,
            sets: &sets,
            exactPairs: exactPairs,
            burstPairs: burstPairs
        )
    }

    // MARK: - Pass 1: identical fingerprints

    /// Joins assets sharing a hash, and returns one representative index per
    /// distinct hash. Later passes work on representatives only, so a library
    /// with 5,000 copies of the same image costs one comparison, not 12 million.
    private func unionExactDuplicates(
        _ items: [(asset: MediaAsset, hash: UInt64)],
        into sets: inout UnionFind,
        exact: inout Set<Int>
    ) -> [Int] {
        var firstIndexForHash: [UInt64: Int] = [:]
        firstIndexForHash.reserveCapacity(items.count)
        var representatives: [Int] = []

        for index in items.indices {
            let hash = items[index].hash
            if let first = firstIndexForHash[hash] {
                sets.union(first, index)
                // Same fingerprint *and* same dimensions is a real duplicate
                // rather than a crop or a re-export.
                if items[first].asset.pixelWidth == items[index].asset.pixelWidth,
                   items[first].asset.pixelHeight == items[index].asset.pixelHeight {
                    exact.insert(first)
                    exact.insert(index)
                }
            } else {
                firstIndexForHash[hash] = index
                representatives.append(index)
            }
        }
        return representatives
    }

    // MARK: - Pass 2: bursts and retries

    private func unionBursts(
        _ items: [(asset: MediaAsset, hash: UInt64)],
        into sets: inout UnionFind,
        burst: inout Set<Int>
    ) {
        for index in items.indices {
            guard let date = items[index].asset.creationDate else { continue }
            let limit = min(index + configuration.windowLookahead, items.count - 1)
            guard limit > index else { continue }

            for next in (index + 1)...limit {
                guard let nextDate = items[next].asset.creationDate else { continue }
                // Sorted by date, so once we are past the window we are done.
                guard nextDate.timeIntervalSince(date) <= configuration.burstWindow else { break }

                let distance = PerceptualHash.hammingDistance(items[index].hash, items[next].hash)
                if distance <= configuration.burstDistance {
                    sets.union(index, next)
                    burst.insert(index)
                    burst.insert(next)
                }
            }
        }
    }

    // MARK: - Pass 3: look-alikes far apart in time

    private func unionLookalikes(
        _ items: [(asset: MediaAsset, hash: UInt64)],
        representatives: [Int],
        into sets: inout UnionFind
    ) {
        guard representatives.count > 1 else { return }

        for band in 0..<configuration.bandCount {
            var buckets: [UInt64: [Int]] = [:]
            for index in representatives {
                let key = PerceptualHash.bands(
                    of: items[index].hash,
                    bandCount: configuration.bandCount
                )[band]
                buckets[key, default: []].append(index)
            }

            for bucket in buckets.values {
                guard bucket.count > 1, bucket.count <= configuration.maximumBucketSize else { continue }
                for i in 0..<(bucket.count - 1) {
                    for j in (i + 1)..<bucket.count {
                        let lhs = bucket[i]
                        let rhs = bucket[j]
                        let distance = PerceptualHash.hammingDistance(items[lhs].hash, items[rhs].hash)
                        if distance <= configuration.similarDistance {
                            sets.union(lhs, rhs)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Assembling results

    private func buildGroups(
        _ items: [(asset: MediaAsset, hash: UInt64)],
        sets: inout UnionFind,
        exactPairs: Set<Int>,
        burstPairs: Set<Int>
    ) -> [PhotoGroup] {
        sets.groups()
            .compactMap { indices -> PhotoGroup? in
                let assets = indices.map { items[$0].asset }
                guard assets.count > 1, let best = selector.best(in: assets) else { return nil }

                let reason: PhotoGroup.Reason
                if indices.allSatisfy(exactPairs.contains) {
                    reason = .exactDuplicate
                } else if indices.contains(where: burstPairs.contains) {
                    reason = .burst
                } else {
                    reason = .similar
                }

                return PhotoGroup(
                    id: assets[0].id,
                    assets: assets,
                    bestAssetID: best.id,
                    reason: reason
                )
            }
            // Biggest win first: that is the order a user cleaning up wants.
            .sorted { lhs, rhs in
                lhs.reclaimableBytes == rhs.reclaimableBytes
                    ? lhs.id < rhs.id
                    : lhs.reclaimableBytes > rhs.reclaimableBytes
            }
    }
}
