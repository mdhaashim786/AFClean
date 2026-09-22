//
//  CleanupSelectionStore.swift
//  AF Clean
//

import Foundation
import Observation

/// The basket: everything the user has picked out for removal, across all four
/// categories.
///
/// App-scoped so selections survive navigating between categories and converge
/// into one review step, which is the core loop the brief describes. It holds
/// intent only — it can describe a clean-up but cannot perform one. Turning it
/// into something executable is `BuildCleanupPlanUseCase`'s job, and acting on
/// that is `ExecuteCleanupUseCase`'s.
@MainActor
@Observable
final class CleanupSelectionStore {

    private(set) var selectedAssetIDs: Set<String> = []
    /// Kept so the review screen can show what is in the basket without
    /// re-fetching or depending on the scan results still being loaded.
    private(set) var selectedAssets: [String: MediaAsset] = [:]
    private(set) var contactDecisions: [String: BuildCleanupPlanUseCase.ContactDecision] = [:]

    private let buildPlan = BuildCleanupPlanUseCase()

    // MARK: - Queries

    var isEmpty: Bool { selectedAssetIDs.isEmpty && contactDecisions.isEmpty }

    func isSelected(_ assetID: String) -> Bool {
        selectedAssetIDs.contains(assetID)
    }

    func decision(for groupID: String) -> BuildCleanupPlanUseCase.ContactDecision? {
        contactDecisions[groupID]
    }

    var totalItemCount: Int {
        selectedAssetIDs.count + contactDecisions.values.reduce(0) { $0 + $1.group.duplicates.count }
    }

    var totalBytes: Int64 {
        selectedAssets.values.reduce(0) { $0 + $1.byteSize }
    }

    func assets(in category: CleanCategory) -> [MediaAsset] {
        let kind: MediaAsset.Kind
        switch category {
        case .similarPhotos: kind = .photo
        case .screenshots: kind = .screenshot
        case .largeVideos: kind = .video
        case .duplicateContacts: return []
        }
        return selectedAssets.values
            .filter { $0.kind == kind }
            .sorted { $0.byteSize > $1.byteSize }
    }

    func itemCount(in category: CleanCategory) -> Int {
        category == .duplicateContacts
            ? contactDecisions.values.reduce(0) { $0 + $1.group.duplicates.count }
            : assets(in: category).count
    }

    func bytes(in category: CleanCategory) -> Int64 {
        assets(in: category).totalBytes
    }

    // MARK: - Media selection

    func toggle(_ asset: MediaAsset) {
        if selectedAssetIDs.contains(asset.id) {
            deselect(asset.id)
        } else {
            select(asset)
        }
    }

    func select(_ asset: MediaAsset) {
        selectedAssetIDs.insert(asset.id)
        selectedAssets[asset.id] = asset
    }

    func select(_ assets: [MediaAsset]) {
        for asset in assets { select(asset) }
    }

    func deselect(_ assetID: String) {
        selectedAssetIDs.remove(assetID)
        selectedAssets.removeValue(forKey: assetID)
    }

    func deselect(_ assets: [MediaAsset]) {
        for asset in assets { deselect(asset.id) }
    }

    func setSelection(_ isSelected: Bool, for assets: [MediaAsset]) {
        isSelected ? select(assets) : deselect(assets)
    }

    func areAllSelected(_ assets: [MediaAsset]) -> Bool {
        !assets.isEmpty && assets.allSatisfy { selectedAssetIDs.contains($0.id) }
    }

    // MARK: - Contact selection

    func setDecision(
        _ action: CleanupPlan.ContactOperation.Action,
        for group: ContactDuplicateGroup
    ) {
        contactDecisions[group.id] = .init(group: group, action: action)
    }

    func clearDecision(for groupID: String) {
        contactDecisions.removeValue(forKey: groupID)
    }

    func toggleDecision(
        _ action: CleanupPlan.ContactOperation.Action,
        for group: ContactDuplicateGroup
    ) {
        if contactDecisions[group.id]?.action == action {
            clearDecision(for: group.id)
        } else {
            setDecision(action, for: group)
        }
    }

    // MARK: - Producing a plan

    func makePlan() -> CleanupPlan {
        buildPlan(
            assets: selectedAssets.values.sorted { $0.byteSize > $1.byteSize },
            contactDecisions: Array(contactDecisions.values)
        )
    }

    // MARK: - Clearing

    func clear(_ category: CleanCategory) {
        if category == .duplicateContacts {
            contactDecisions.removeAll()
        } else {
            deselect(assets(in: category))
        }
    }

    func clearAll() {
        selectedAssetIDs.removeAll()
        selectedAssets.removeAll()
        contactDecisions.removeAll()
    }

    /// Drops anything that no longer exists — after a clean-up, or after the
    /// library changed underneath us.
    func pruneMissing(assetIDs: Set<String>, contactGroupIDs: Set<String>) {
        for id in selectedAssetIDs where !assetIDs.contains(id) {
            deselect(id)
        }
        for id in contactDecisions.keys where !contactGroupIDs.contains(id) {
            clearDecision(for: id)
        }
    }
}
