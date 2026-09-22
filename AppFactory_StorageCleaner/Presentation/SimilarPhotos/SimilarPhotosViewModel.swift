//
//  SimilarPhotosViewModel.swift
//  AF Clean
//

import Observation

@MainActor
@Observable
final class SimilarPhotosViewModel {

    let scans: ScanCoordinator
    let selection: CleanupSelectionStore
    let permissions: PermissionsViewModel
    let thumbnails: ThumbnailRepository

    /// Set once so re-entering the screen does not undo the user's edits.
    private var hasAppliedInitialSelection = false

    init(
        scans: ScanCoordinator,
        selection: CleanupSelectionStore,
        permissions: PermissionsViewModel,
        thumbnails: ThumbnailRepository
    ) {
        self.scans = scans
        self.selection = selection
        self.permissions = permissions
        self.thumbnails = thumbnails
    }

    // MARK: - View state

    var groups: [PhotoGroup] { scans.similarGroups }
    var state: ScanCoordinator.CategoryState { scans.state(for: .similarPhotos) }

    var selectedCount: Int { selection.itemCount(in: .similarPhotos) }
    var selectedBytes: Int64 { selection.bytes(in: .similarPhotos) }

    var summary: String {
        let removable = groups.totalRemovableCount
        guard removable > 0 else { return "Nothing to clean" }
        return "\(Format.count(groups.count, singular: "group")) · \(Format.count(removable, singular: "photo")) · \(Format.bytes(groups.totalReclaimableBytes))"
    }

    var areAllOthersSelected: Bool {
        let others = groups.flatMap(\.others)
        return !others.isEmpty && selection.areAllSelected(others)
    }

    func isSelected(_ asset: MediaAsset) -> Bool {
        selection.isSelected(asset.id)
    }

    func isBest(_ asset: MediaAsset, in group: PhotoGroup) -> Bool {
        group.bestAssetID == asset.id
    }

    func areAllOthersSelected(in group: PhotoGroup) -> Bool {
        selection.areAllSelected(group.others)
    }

    // MARK: - Intents

    private static let prefetchLimit = 240

    func onAppear() {
        scans.scanIfNeeded(.similarPhotos)
        applyInitialSelectionIfNeeded()
        thumbnails.startCaching(
            assetIDs: Array(groups.flatMap(\.assets).prefix(Self.prefetchLimit)).map(\.id),
            maxPixel: 300
        )
    }

    func onDisappear() {
        thumbnails.stopCachingAll()
    }

    /// Pre-selects every photo except the best one in each group, which is the
    /// behaviour the brief asks for: mark the best, offer the rest. The keeper
    /// is never selected automatically, so the default action can only ever
    /// leave at least one copy of every shot.
    private func applyInitialSelectionIfNeeded() {
        guard !hasAppliedInitialSelection, !groups.isEmpty, selection.isEmpty else { return }
        hasAppliedInitialSelection = true
        selection.select(groups.flatMap(\.others))
    }

    func toggle(_ asset: MediaAsset, in group: PhotoGroup) {
        // Guard the keeper: deselecting everything else and then selecting the
        // best would let a group be wiped out entirely by accident.
        selection.toggle(asset)
        ensureSurvivor(in: group)
        Haptics.select()
    }

    func toggleAllOthers(in group: PhotoGroup) {
        selection.setSelection(!areAllOthersSelected(in: group), for: group.others)
    }

    func toggleSelectAll() {
        let others = groups.flatMap(\.others)
        selection.setSelection(!areAllOthersSelected, for: others)
    }

    func clearSelection() {
        selection.clear(.similarPhotos)
    }

    /// Never let every photo in a group end up selected — something has to
    /// survive, otherwise "keep the best" silently becomes "delete them all".
    private func ensureSurvivor(in group: PhotoGroup) {
        guard group.assets.allSatisfy({ selection.isSelected($0.id) }) else { return }
        selection.deselect(group.best.id)
    }
}
