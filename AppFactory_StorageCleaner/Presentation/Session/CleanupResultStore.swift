//
//  CleanupResultStore.swift
//  AF Clean
//

import Observation

/// Holds the outcome of the last clean-up.
///
/// The review screen is popped off the stack as soon as a clean-up completes —
/// going "back" to a review of items that no longer exist would be wrong — so
/// the result has to outlive the view model that produced it.
@MainActor
@Observable
final class CleanupResultStore {

    private(set) var outcome: CleanupOutcome = .none
    /// Device storage measured *after* the clean-up, so the result screen can
    /// report the real free space rather than a stale figure.
    private(set) var storageAfter: StorageSnapshot = .unknown

    func record(_ outcome: CleanupOutcome, storageAfter: StorageSnapshot) {
        self.outcome = outcome
        self.storageAfter = storageAfter
    }

    func clear() {
        outcome = .none
        storageAfter = .unknown
    }
}
