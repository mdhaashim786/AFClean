//
//  PerceptualHash.swift
//  AF Clean
//

import Foundation

/// Helpers for the 64-bit difference hashes the similarity scan compares.
enum PerceptualHash {

    /// Number of differing bits. Two photos of the same scene land within a
    /// handful of bits of each other; unrelated photos are typically 25+ apart.
    static func hammingDistance(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        (lhs ^ rhs).nonzeroBitCount
    }

    /// Splits a hash into `bandCount` equal slices.
    ///
    /// This is the locality-sensitive hashing trick: if two hashes differ by at
    /// most `d` bits, those differences cannot touch every band at once, so at
    /// least one band must match exactly. Bucketing on bands therefore finds
    /// near-duplicates without ever comparing all pairs.
    static func bands(of hash: UInt64, bandCount: Int) -> [UInt64] {
        guard bandCount > 0, bandCount <= 64 else { return [hash] }
        let width = 64 / bandCount
        let mask: UInt64 = width >= 64 ? .max : (1 << UInt64(width)) - 1
        return (0..<bandCount).map { index in
            (hash >> UInt64(index * width)) & mask
        }
    }
}
