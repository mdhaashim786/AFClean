//
//  StorageSnapshot.swift
//  AF Clean
//

import Foundation

/// Device capacity at a point in time.
struct StorageSnapshot: Sendable, Equatable {

    let totalBytes: Int64
    let freeBytes: Int64

    static let unknown = StorageSnapshot(totalBytes: 0, freeBytes: 0)

    var usedBytes: Int64 { max(0, totalBytes - freeBytes) }

    var usedFraction: Double {
        totalBytes > 0 ? min(1, Double(usedBytes) / Double(totalBytes)) : 0
    }

    var isKnown: Bool { totalBytes > 0 }
}
