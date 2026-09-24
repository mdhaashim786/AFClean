//
//  ReviewViewModel.swift
//  AF Clean
//

import Foundation
import Observation

/// The safety gate.
///
/// Everything the user selected converges here, is shown back to them item by
/// item, and only leaves as a `CleanupPlan` once they confirm. Items can still
/// be pulled out of the basket at this point.
@MainActor
@Observable
final class ReviewViewModel {

    enum Stage: Equatable {
        case reviewing
        case confirming
        case deleting
        case finished(CleanupOutcome)
    }

    private(set) var stage: Stage = .reviewing
    private(set) var outcome: CleanupOutcome = .none

    let selection: CleanupSelectionStore
    let thumbnails: ThumbnailRepository

    private let executeCleanup: ExecuteCleanupUseCase
    private let getStorageSnapshot: GetStorageSnapshotUseCase
    private let scans: ScanCoordinator
    private let results: CleanupResultStore
    private let router: AppRouter

    init(
        selection: CleanupSelectionStore,
        thumbnails: ThumbnailRepository,
        executeCleanup: ExecuteCleanupUseCase,
        getStorageSnapshot: GetStorageSnapshotUseCase,
        scans: ScanCoordinator,
        results: CleanupResultStore,
        router: AppRouter
    ) {
        self.selection = selection
        self.thumbnails = thumbnails
        self.executeCleanup = executeCleanup
        self.getStorageSnapshot = getStorageSnapshot
        self.scans = scans
        self.results = results
        self.router = router
    }

    // MARK: - View state

    var plan: CleanupPlan { selection.makePlan() }

    var isEmpty: Bool { selection.isEmpty }
    var isDeleting: Bool { stage == .deleting }

    var totalItemCount: Int { selection.totalItemCount }
    var totalBytes: Int64 { selection.totalBytes }

    /// Only the categories that actually contribute something, so the review
    /// list never shows an empty section.
    var populatedCategories: [CleanCategory] {
        CleanCategory.allCases.filter { selection.itemCount(in: $0) > 0 }
    }

    func assets(in category: CleanCategory) -> [MediaAsset] {
        selection.assets(in: category)
    }

    var contactDecisions: [BuildCleanupPlanUseCase.ContactDecision] {
        selection.contactDecisions.values.sorted {
            $0.group.keeper.displayName.localizedCaseInsensitiveCompare(
                $1.group.keeper.displayName
            ) == .orderedAscending
        }
    }

    var hasContactChanges: Bool { !selection.contactDecisions.isEmpty }

    var confirmTitle: String {
        "Delete \(Format.count(totalItemCount, singular: "item"))?"
    }

    /// Spells out both halves of what is about to happen, including the part
    /// that cannot be undone.
    var confirmMessage: String {
        var parts: [String] = []

        let mediaCount = plan.assetCount
        if mediaCount > 0 {
            parts.append(
                "\(Format.count(mediaCount, singular: "photo or video", plural: "photos or videos")) will move to Recently Deleted, where you can restore them for 30 days. iOS will ask you to confirm as well."
            )
        }
        if hasContactChanges {
            parts.append(
                "\(Format.count(plan.contactRemovalCount, singular: "duplicate contact")) will be removed. Contact changes cannot be undone."
            )
        }
        return parts.joined(separator: "\n\n")
    }

    // MARK: - Intents

    func remove(_ asset: MediaAsset) {
        selection.deselect(asset.id)
    }

    /// Empties the whole basket in one go, rather than making the user tap the
    /// cross on every single row.
    func discardAll() {
        selection.clearAll()
        Haptics.select()
    }

    /// Same, for one category — useful when the user wants to keep their photo
    /// choices but drop, say, every video.
    func discard(_ category: CleanCategory) {
        selection.clear(category)
        Haptics.select()
    }

    func removeContactDecision(_ decision: BuildCleanupPlanUseCase.ContactDecision) {
        selection.clearDecision(for: decision.group.id)
    }

    func askForConfirmation() {
        guard !isEmpty else { return }
        stage = .confirming
    }

    func cancelConfirmation() {
        guard stage == .confirming else { return }
        stage = .reviewing
    }

    /// The single place the app commits. Runs the plan, reports what actually
    /// happened, and only then updates the results and clears the basket.
    func confirmDelete() async {
        guard !isEmpty else { return }
        let plan = self.plan
        stage = .deleting

        let result = await executeCleanup(plan: plan)
        outcome = result

        // Only forget what genuinely went away. If iOS's sheet was cancelled,
        // the selection is still valid and the user keeps their work.
        if result.deletedAssetCount > 0 || result.removedContactCount > 0 {
            let deletedAssetIDs = result.deletedAssetCount > 0
                ? Set(plan.assets.map(\.id))
                : []
            let removedContactIDs = result.removedContactCount > 0
                ? Set(plan.contactOperations.flatMap { $0.removed.map(\.id) })
                : []

            scans.removeDeleted(assetIDs: deletedAssetIDs, contactIDs: removedContactIDs)
            selection.clearAll()
        }

        if result.wasCancelled, !result.didAnything {
            // Nothing happened — stay on the review screen with the basket
            // intact rather than claiming a result.
            stage = .reviewing
            return
        }

        stage = .finished(result)
        result.hasFailures ? Haptics.warning() : Haptics.success()
        results.record(result, storageAfter: getStorageSnapshot())
        router.showResult()
    }

    func finish() {
        router.popToRoot()
    }
}
