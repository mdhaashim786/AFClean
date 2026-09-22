//
//  LargeVideosViewModel.swift
//  AF Clean
//

import Observation

@MainActor
@Observable
final class LargeVideosViewModel {

    let scans: ScanCoordinator
    let selection: CleanupSelectionStore
    let permissions: PermissionsViewModel
    let thumbnails: ThumbnailRepository

    /// The video the user asked to preview before deciding.
    var previewingAsset: MediaAsset?

    private let loadPlayable: LoadPlayableVideoUseCase

    init(
        scans: ScanCoordinator,
        selection: CleanupSelectionStore,
        permissions: PermissionsViewModel,
        thumbnails: ThumbnailRepository,
        loadPlayable: LoadPlayableVideoUseCase
    ) {
        self.scans = scans
        self.selection = selection
        self.permissions = permissions
        self.thumbnails = thumbnails
        self.loadPlayable = loadPlayable
    }

    // MARK: - View state

    /// Already sorted largest first by `FetchLargeVideosUseCase` — the ordering
    /// the brief asks for, and the one that puts the biggest wins on top.
    var videos: [MediaAsset] { scans.videos }
    var state: ScanCoordinator.CategoryState { scans.state(for: .largeVideos) }

    var summary: String {
        guard !videos.isEmpty else { return "Nothing to clean" }
        return "\(Format.count(videos.count, singular: "video")) · \(Format.bytes(videos.totalBytes))"
    }

    var areAllSelected: Bool { selection.areAllSelected(videos) }

    func isSelected(_ asset: MediaAsset) -> Bool { selection.isSelected(asset.id) }

    // MARK: - Intents

    func onAppear() {
        scans.scanIfNeeded(.largeVideos)
    }

    func toggle(_ asset: MediaAsset) {
        selection.toggle(asset)
        Haptics.select()
    }

    func toggleSelectAll() {
        selection.setSelection(!areAllSelected, for: videos)
    }

    func preview(_ asset: MediaAsset) {
        previewingAsset = asset
    }

    func dismissPreview() {
        previewingAsset = nil
    }

    func playerItem(for asset: MediaAsset) async -> PlayableVideo? {
        await loadPlayable(assetID: asset.id)
    }
}
