//
//  ScanCoordinator.swift
//  AF Clean
//

import Foundation
import Observation

/// Owns scanning and its results for the whole app.
///
/// App-scoped rather than per-screen because the dashboard and each category
/// screen are views onto the same results: scanning once and sharing the
/// outcome is both faster and the only way the dashboard totals can agree with
/// what each category shows.
@MainActor
@Observable
final class ScanCoordinator {

    enum CategoryState: Equatable {
        case idle
        case scanning(ScanProgress)
        case ready
        /// Permission is missing, so this category cannot run.
        case blocked(AccessStatus)
        case failed(String)

        var isScanning: Bool {
            if case .scanning = self { return true }
            return false
        }

        var progress: ScanProgress? {
            if case .scanning(let progress) = self { return progress }
            return nil
        }
    }

    // MARK: - Results

    private(set) var similarGroups: [PhotoGroup] = []
    private(set) var screenshots: [MediaAsset] = []
    private(set) var videos: [MediaAsset] = []
    private(set) var contactGroups: [ContactDuplicateGroup] = []

    private(set) var states: [CleanCategory: CategoryState] = [:]
    /// Set when the photo library or address book changes underneath us, so the
    /// UI can offer a re-scan rather than quietly showing stale results.
    private(set) var hasStaleResults = false
    private(set) var hasEverScanned = false

    // MARK: - Dependencies

    private let scanSimilarPhotos: ScanSimilarPhotosUseCase
    private let fetchScreenshots: FetchScreenshotsUseCase
    private let fetchLargeVideos: FetchLargeVideosUseCase
    private let scanDuplicateContacts: ScanDuplicateContactsUseCase
    private let permissions: PermissionsViewModel
    private let photoAssets: PhotoAssetRepository
    private let contacts: ContactRepository

    private var tasks: [CleanCategory: Task<Void, Never>] = [:]
    private var hasRegisteredPhotoObserver = false
    private var hasRegisteredContactObserver = false

    init(
        scanSimilarPhotos: ScanSimilarPhotosUseCase,
        fetchScreenshots: FetchScreenshotsUseCase,
        fetchLargeVideos: FetchLargeVideosUseCase,
        scanDuplicateContacts: ScanDuplicateContactsUseCase,
        permissions: PermissionsViewModel,
        photoAssets: PhotoAssetRepository,
        contacts: ContactRepository
    ) {
        self.scanSimilarPhotos = scanSimilarPhotos
        self.fetchScreenshots = fetchScreenshots
        self.fetchLargeVideos = fetchLargeVideos
        self.scanDuplicateContacts = scanDuplicateContacts
        self.permissions = permissions
        self.photoAssets = photoAssets
        self.contacts = contacts

        for category in CleanCategory.allCases {
            states[category] = .idle
        }
    }

    /// Change observers are registered lazily, never in `init`.
    ///
    /// Registering as a PHPhotoLibrary observer touches `PHPhotoLibrary.shared()`,
    /// which is enough to make iOS raise its permission alert. Doing that at
    /// startup would fire the system prompt over our own priming screen —
    /// exactly the thing the priming screen exists to avoid — and would spend
    /// the single prompt iOS allows before the user had been told why.
    private func registerObserversIfNeeded(for category: CleanCategory) {
        if category == .duplicateContacts {
            guard !hasRegisteredContactObserver else { return }
            hasRegisteredContactObserver = true
            contacts.observeContactChanges { [weak self] in
                Task { @MainActor in self?.markStale() }
            }
        } else {
            guard !hasRegisteredPhotoObserver else { return }
            hasRegisteredPhotoObserver = true
            photoAssets.observeLibraryChanges { [weak self] in
                Task { @MainActor in self?.markStale() }
            }
        }
    }

    // MARK: - Derived totals

    func state(for category: CleanCategory) -> CategoryState {
        states[category] ?? .idle
    }

    /// How many items this category is offering to remove.
    func itemCount(for category: CleanCategory) -> Int {
        switch category {
        case .similarPhotos: similarGroups.totalRemovableCount
        case .screenshots: screenshots.count
        case .largeVideos: videos.count
        case .duplicateContacts: contactGroups.reduce(0) { $0 + $1.duplicates.count }
        }
    }

    /// Space this category could free. Contacts free a negligible and
    /// unknowable amount, so they never claim one.
    func reclaimableBytes(for category: CleanCategory) -> Int64 {
        switch category {
        case .similarPhotos: similarGroups.totalReclaimableBytes
        case .screenshots: screenshots.totalBytes
        case .largeVideos: videos.totalBytes
        case .duplicateContacts: 0
        }
    }

    /// Representative thumbnails for the dashboard cards.
    func previewAssetIDs(for category: CleanCategory, limit: Int = 4) -> [String] {
        switch category {
        case .similarPhotos: similarGroups.prefix(limit).map(\.best.id)
        case .screenshots: screenshots.prefix(limit).map(\.id)
        case .largeVideos: videos.prefix(limit).map(\.id)
        case .duplicateContacts: []
        }
    }

    var totalItemCount: Int {
        CleanCategory.allCases.reduce(0) { $0 + itemCount(for: $1) }
    }

    var totalReclaimableBytes: Int64 {
        CleanCategory.allCases.reduce(0) { $0 + reclaimableBytes(for: $1) }
    }

    var isScanning: Bool {
        states.values.contains { $0.isScanning }
    }

    // MARK: - Scanning

    func scanAll() {
        for category in CleanCategory.allCases {
            scan(category)
        }
        hasEverScanned = true
        hasStaleResults = false
    }

    func rescanAll() {
        cancelAll()
        scanAll()
    }

    func scanIfNeeded(_ category: CleanCategory) {
        guard state(for: category) == .idle else { return }
        scan(category)
    }

    func scan(_ category: CleanCategory) {
        tasks[category]?.cancel()

        // Refuse to start rather than showing an empty result that looks like
        // "nothing to clean" when the truth is "we were not allowed to look".
        let status = category == .duplicateContacts
            ? permissions.contactsStatus
            : permissions.photoStatus
        guard status.canRead else {
            states[category] = .blocked(status)
            return
        }

        // Safe now: we only reach here with access already granted, so
        // registering cannot surprise the user with a prompt.
        registerObserversIfNeeded(for: category)

        states[category] = .scanning(ScanProgress(phase: .fetching))

        tasks[category] = Task { [weak self] in
            await self?.run(category)
        }
    }

    private func run(_ category: CleanCategory) async {
        switch category {
        case .similarPhotos:
            let groups = await scanSimilarPhotos { [weak self] progress in
                Task { @MainActor in self?.apply(progress, to: .similarPhotos) }
            }
            guard !Task.isCancelled else { return }
            similarGroups = groups

        case .screenshots:
            let assets = await fetchScreenshots()
            guard !Task.isCancelled else { return }
            screenshots = assets

        case .largeVideos:
            let assets = await fetchLargeVideos()
            guard !Task.isCancelled else { return }
            videos = assets

        case .duplicateContacts:
            do {
                let groups = try await scanDuplicateContacts()
                guard !Task.isCancelled else { return }
                contactGroups = groups
            } catch {
                guard !Task.isCancelled else { return }
                states[.duplicateContacts] = .failed("Could not read your contacts.")
                return
            }
        }

        states[category] = .ready
    }

    /// Applies a progress update, but only while the category is still
    /// scanning.
    ///
    /// Progress is delivered from a background task and hops to the main actor,
    /// so the final update can arrive *after* the scan has already finished and
    /// set `.ready`. Without this guard that late update reinstates
    /// `.scanning`, leaving the card stuck on a full progress bar forever.
    private func apply(_ progress: ScanProgress, to category: CleanCategory) {
        guard states[category]?.isScanning == true else { return }
        states[category] = .scanning(progress)
    }

    func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        for category in CleanCategory.allCases where states[category]?.isScanning == true {
            states[category] = .idle
        }
    }

    // MARK: - Reacting to change

    private func markStale() {
        // Only worth flagging once there is something on screen to go stale.
        guard hasEverScanned, !isScanning else { return }
        hasStaleResults = true
    }

    /// Called after a successful clean-up so results match reality without
    /// paying for a full re-scan.
    func removeDeleted(assetIDs: Set<String>, contactIDs: Set<String>) {
        if !assetIDs.isEmpty {
            screenshots.removeAll { assetIDs.contains($0.id) }
            videos.removeAll { assetIDs.contains($0.id) }
            similarGroups = similarGroups.compactMap { group in
                let remaining = group.assets.filter { !assetIDs.contains($0.id) }
                // A group with one photo left is no longer a duplicate group.
                guard remaining.count > 1 else { return nil }
                let bestID = remaining.contains(where: { $0.id == group.bestAssetID })
                    ? group.bestAssetID
                    : remaining[0].id
                return PhotoGroup(
                    id: group.id,
                    assets: remaining,
                    bestAssetID: bestID,
                    reason: group.reason
                )
            }
        }

        if !contactIDs.isEmpty {
            contactGroups = contactGroups.compactMap { group in
                let remaining = group.contacts.filter { !contactIDs.contains($0.id) }
                guard remaining.count > 1, let keeper = remaining.first else { return nil }
                return ContactDuplicateGroup(
                    id: group.id,
                    contacts: remaining,
                    keeperID: remaining.contains(where: { $0.id == group.keeperID })
                        ? group.keeperID
                        : keeper.id,
                    reasons: group.reasons
                )
            }
        }

        hasStaleResults = false
    }
}
