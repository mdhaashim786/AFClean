//
//  ScreenshotsViewModel.swift
//  AF Clean
//

import Foundation
import Observation

@MainActor
@Observable
final class ScreenshotsViewModel {

    struct Section: Identifiable {
        let id: String
        let title: String
        let assets: [MediaAsset]
        var totalBytes: Int64 { assets.totalBytes }
    }

    let scans: ScanCoordinator
    let selection: CleanupSelectionStore
    let permissions: PermissionsViewModel
    let thumbnails: ThumbnailRepository

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

    var screenshots: [MediaAsset] { scans.screenshots }
    var state: ScanCoordinator.CategoryState { scans.state(for: .screenshots) }

    /// Grouped by month so "select many at once" is a single tap on a heading
    /// rather than a long drag through hundreds of thumbnails.
    var sections: [Section] {
        let calendar = Calendar.current
        var order: [String] = []
        var buckets: [String: [MediaAsset]] = [:]

        for asset in screenshots {
            let date = asset.creationDate ?? .distantPast
            let components = calendar.dateComponents([.year, .month], from: date)
            let key = "\(components.year ?? 0)-\(components.month ?? 0)"
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(asset)
        }

        return order.compactMap { key in
            guard let assets = buckets[key], let first = assets.first else { return nil }
            return Section(
                id: key,
                title: first.creationDate.map(Format.month) ?? "Undated",
                assets: assets
            )
        }
    }

    var summary: String {
        guard !screenshots.isEmpty else { return "Nothing to clean" }
        return "\(Format.count(screenshots.count, singular: "screenshot")) · \(Format.bytes(screenshots.totalBytes))"
    }

    var areAllSelected: Bool { selection.areAllSelected(screenshots) }

    func isSelected(_ asset: MediaAsset) -> Bool { selection.isSelected(asset.id) }

    func areAllSelected(in section: Section) -> Bool {
        selection.areAllSelected(section.assets)
    }

    // MARK: - Intents

    func onAppear() {
        scans.scanIfNeeded(.screenshots)
    }

    /// Nothing is pre-selected here. Unlike a duplicate group, a screenshot has
    /// no "extra copy" to fall back on — deleting it loses the only one — so
    /// the user picks every item deliberately.
    func toggle(_ asset: MediaAsset) {
        selection.toggle(asset)
    }

    func toggleAll(in section: Section) {
        selection.setSelection(!areAllSelected(in: section), for: section.assets)
    }

    func toggleSelectAll() {
        selection.setSelection(!areAllSelected, for: screenshots)
    }
}
