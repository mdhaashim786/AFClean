//
//  DashboardViewModel.swift
//  AF Clean
//

import Observation

@MainActor
@Observable
final class DashboardViewModel {

    private(set) var storage: StorageSnapshot = .unknown

    let scans: ScanCoordinator
    let selection: CleanupSelectionStore
    let permissions: PermissionsViewModel
    let thumbnails: ThumbnailRepository

    private let getStorageSnapshot: GetStorageSnapshotUseCase
    private let router: AppRouter

    init(
        getStorageSnapshot: GetStorageSnapshotUseCase,
        scans: ScanCoordinator,
        selection: CleanupSelectionStore,
        permissions: PermissionsViewModel,
        thumbnails: ThumbnailRepository,
        router: AppRouter
    ) {
        self.getStorageSnapshot = getStorageSnapshot
        self.scans = scans
        self.selection = selection
        self.permissions = permissions
        self.thumbnails = thumbnails
        self.router = router
    }

    // MARK: - View state

    var totalItemCount: Int { scans.totalItemCount }
    var totalReclaimableBytes: Int64 { scans.totalReclaimableBytes }
    var isScanning: Bool { scans.isScanning }
    var hasStaleResults: Bool { scans.hasStaleResults }

    /// Headline under the ring. Reflects what is actually happening rather than
    /// always claiming a number.
    var headline: String {
        if isScanning { return "Looking through your library…" }
        if !scans.hasEverScanned { return "Ready to scan" }
        if totalItemCount == 0 { return "Nothing to clean up" }
        return "\(Format.count(totalItemCount, singular: "item")) · \(Format.bytes(totalReclaimableBytes)) to free"
    }

    var selectedItemCount: Int { selection.totalItemCount }
    var selectedBytes: Int64 { selection.totalBytes }
    var hasSelection: Bool { !selection.isEmpty }

    // MARK: - Intents

    func onAppear() {
        refreshStorage()
        if !scans.hasEverScanned {
            scans.scanAll()
        }
        #if DEBUG
        applyDebugLaunchRouteIfNeeded()
        #endif
    }

    #if DEBUG
    /// Waits for the scans to settle, then jumps to the requested screen.
    private func applyDebugLaunchRouteIfNeeded() {
        guard let route = DebugLaunchRoute.requested() else { return }
        Task {
            while scans.isScanning {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            if DebugLaunchRoute.shouldPreselect() {
                selection.select(scans.similarGroups.flatMap(\.others))
                selection.select(scans.screenshots)
                selection.select(scans.videos)
            }
            router.push(route)
        }
    }
    #endif

    func refreshStorage() {
        storage = getStorageSnapshot()
    }

    func rescan() {
        refreshStorage()
        // Selections may point at items a re-scan will not return.
        selection.clearAll()
        scans.rescanAll()
    }

    func open(_ category: CleanCategory) {
        router.push(.category(category))
    }

    func openReview() {
        router.push(.review)
    }
}
