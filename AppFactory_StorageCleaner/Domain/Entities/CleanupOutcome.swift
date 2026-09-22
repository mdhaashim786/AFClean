//
//  CleanupOutcome.swift
//  AF Clean
//

import Foundation

/// What actually happened when a `CleanupPlan` ran.
///
/// Deliberately separate from the plan: the user can cancel iOS's own deletion
/// sheet, and individual contact writes can fail. We report what really
/// happened rather than assuming the plan succeeded.
struct CleanupOutcome: Sendable, Equatable {

    var deletedAssetCount: Int = 0
    var bytesFreed: Int64 = 0
    var mergedContactCount: Int = 0
    var deletedContactCount: Int = 0
    /// User-readable descriptions of anything that did not go through.
    var failures: [String] = []
    /// The user backed out at iOS's confirmation sheet.
    var wasCancelled: Bool = false

    static let none = CleanupOutcome()

    var removedContactCount: Int { mergedContactCount + deletedContactCount }

    var totalRemovedCount: Int { deletedAssetCount + removedContactCount }

    var didAnything: Bool { totalRemovedCount > 0 }

    var hasFailures: Bool { !failures.isEmpty }
}
