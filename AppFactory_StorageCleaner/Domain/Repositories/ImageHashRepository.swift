//
//  ImageHashRepository.swift
//  AF Clean
//

import Foundation

/// Produces the perceptual fingerprints the similarity scan groups on.
protocol ImageHashRepository: Sendable {

    /// Perceptual hash per asset id. Implementations are expected to serve
    /// unchanged assets from a persistent cache so repeat scans are cheap.
    ///
    /// - Parameter onProgress: called as work completes, with
    ///   `(processed, total, cacheHits)`.
    func hashes(
        for assets: [MediaAsset],
        onProgress: @Sendable @escaping (Int, Int, Int) -> Void
    ) async -> [String: UInt64]

    /// Vision feature-print distance between two assets, used to double-check
    /// candidate pairs the cheap hash flagged. `nil` when it cannot be computed.
    func featureDistance(between lhs: String, and rhs: String) async -> Float?
}
