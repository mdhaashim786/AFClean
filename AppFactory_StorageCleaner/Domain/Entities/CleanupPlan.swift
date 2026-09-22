//
//  CleanupPlan.swift
//  AF Clean
//
//  The single, explicit description of what the user has approved for removal.
//  Nothing in the app deletes anything that is not in one of these.
//

import Foundation

struct CleanupPlan: Sendable, Equatable {

    struct ContactOperation: Identifiable, Sendable, Equatable {
        enum Action: String, Sendable {
            /// Fold the duplicates into the keeper, then remove them.
            case merge
            /// Remove the duplicates and leave the keeper untouched.
            case delete
        }

        let id: String
        let action: Action
        let keeper: ContactRecord
        let removed: [ContactRecord]
    }

    /// Photo library items to delete, in the order shown to the user.
    var assets: [MediaAsset] = []
    var contactOperations: [ContactOperation] = []

    static let empty = CleanupPlan()

    var isEmpty: Bool { assets.isEmpty && contactOperations.isEmpty }

    var assetCount: Int { assets.count }

    var contactRemovalCount: Int {
        contactOperations.reduce(0) { $0 + $1.removed.count }
    }

    var totalItemCount: Int { assetCount + contactRemovalCount }

    /// Only media has a byte size; removing a contact frees a negligible and
    /// unknowable amount, so we never claim a number for it.
    var reclaimableBytes: Int64 { assets.totalBytes }

    func assets(in category: CleanCategory) -> [MediaAsset] {
        switch category {
        case .similarPhotos: assets.filter { $0.kind == .photo }
        case .screenshots: assets.filter { $0.kind == .screenshot }
        case .largeVideos: assets.filter { $0.kind == .video }
        case .duplicateContacts: []
        }
    }

    func itemCount(in category: CleanCategory) -> Int {
        category == .duplicateContacts ? contactRemovalCount : assets(in: category).count
    }

    func reclaimableBytes(in category: CleanCategory) -> Int64 {
        assets(in: category).totalBytes
    }
}
