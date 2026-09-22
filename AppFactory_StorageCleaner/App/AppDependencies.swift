//
//  AppDependencies.swift
//  AF Clean
//
//  Composition root. The single place where concrete implementations are
//  chosen and wired to the protocols the rest of the app depends on.
//
//  Everything else receives what it needs through an initialiser, so no view
//  model reaches for a singleton and every use case can be driven by a fake.
//

import Foundation

@MainActor
final class AppDependencies {

    // MARK: - Shared infrastructure

    private let photoKit = PhotoKitDataSource()
    private let contactStore = ContactStoreDataSource()
    private let analysisCache = AssetAnalysisCache()

    // MARK: - Repositories

    let permissions: PermissionRepository
    let deviceStorage: DeviceStorageRepository
    let photoAssets: PhotoAssetRepository
    let thumbnails: ThumbnailRepository
    let imageHashes: ImageHashRepository
    let contacts: ContactRepository
    /// Concrete type: the view layer needs the AVPlayerItem it holds, which the
    /// protocol deliberately does not expose.
    let videoPlayback: VideoPlaybackRepositoryImpl

    // MARK: - Use cases

    let requestAccess: RequestAccessUseCase
    let getStorageSnapshot: GetStorageSnapshotUseCase
    let scanSimilarPhotos: ScanSimilarPhotosUseCase
    let fetchScreenshots: FetchScreenshotsUseCase
    let fetchLargeVideos: FetchLargeVideosUseCase
    let scanDuplicateContacts: ScanDuplicateContactsUseCase
    let executeCleanup: ExecuteCleanupUseCase
    let loadPlayableVideo: LoadPlayableVideoUseCase

    // MARK: - Shared app-scoped state

    let permissionsViewModel: PermissionsViewModel
    let scans: ScanCoordinator
    let selection: CleanupSelectionStore
    let results: CleanupResultStore
    let router: AppRouter

    init(permissions: PermissionRepository = PermissionRepositoryImpl(),
         deviceStorage: DeviceStorageRepository = DeviceStorageRepositoryImpl()) {

        self.permissions = permissions
        self.deviceStorage = deviceStorage

        let photoAssets = PhotoAssetRepositoryImpl(source: photoKit, cache: analysisCache)
        let thumbnails = ThumbnailRepositoryImpl(source: photoKit)
        let imageHashes = ImageHashRepositoryImpl(source: photoKit, cache: analysisCache)
        let contacts = ContactRepositoryImpl(source: contactStore)
        let videoPlayback = VideoPlaybackRepositoryImpl(source: photoKit)

        self.photoAssets = photoAssets
        self.thumbnails = thumbnails
        self.imageHashes = imageHashes
        self.contacts = contacts
        self.videoPlayback = videoPlayback

        let requestAccess = RequestAccessUseCase(permissions: permissions)
        let scanSimilarPhotos = ScanSimilarPhotosUseCase(photos: photoAssets, hashes: imageHashes)
        let fetchScreenshots = FetchScreenshotsUseCase(photos: photoAssets)
        let fetchLargeVideos = FetchLargeVideosUseCase(photos: photoAssets)
        let scanDuplicateContacts = ScanDuplicateContactsUseCase(contacts: contacts)

        self.requestAccess = requestAccess
        self.getStorageSnapshot = GetStorageSnapshotUseCase(repository: deviceStorage)
        self.scanSimilarPhotos = scanSimilarPhotos
        self.fetchScreenshots = fetchScreenshots
        self.fetchLargeVideos = fetchLargeVideos
        self.scanDuplicateContacts = scanDuplicateContacts
        self.executeCleanup = ExecuteCleanupUseCase(photos: photoAssets, contacts: contacts)
        self.loadPlayableVideo = LoadPlayableVideoUseCase(repository: videoPlayback)

        let permissionsViewModel = PermissionsViewModel(access: requestAccess)
        self.permissionsViewModel = permissionsViewModel
        self.selection = CleanupSelectionStore()
        self.results = CleanupResultStore()
        self.router = AppRouter()
        self.scans = ScanCoordinator(
            scanSimilarPhotos: scanSimilarPhotos,
            fetchScreenshots: fetchScreenshots,
            fetchLargeVideos: fetchLargeVideos,
            scanDuplicateContacts: scanDuplicateContacts,
            permissions: permissionsViewModel,
            photoAssets: photoAssets,
            contacts: contacts
        )
    }

    // MARK: - View model factories

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(
            getStorageSnapshot: getStorageSnapshot,
            scans: scans,
            selection: selection,
            permissions: permissionsViewModel,
            thumbnails: thumbnails,
            router: router
        )
    }

    func makeSimilarPhotosViewModel() -> SimilarPhotosViewModel {
        SimilarPhotosViewModel(
            scans: scans,
            selection: selection,
            permissions: permissionsViewModel,
            thumbnails: thumbnails
        )
    }

    func makeScreenshotsViewModel() -> ScreenshotsViewModel {
        ScreenshotsViewModel(
            scans: scans,
            selection: selection,
            permissions: permissionsViewModel,
            thumbnails: thumbnails
        )
    }

    func makeLargeVideosViewModel() -> LargeVideosViewModel {
        LargeVideosViewModel(
            scans: scans,
            selection: selection,
            permissions: permissionsViewModel,
            thumbnails: thumbnails,
            loadPlayable: loadPlayableVideo
        )
    }

    func makeDuplicateContactsViewModel() -> DuplicateContactsViewModel {
        DuplicateContactsViewModel(
            scans: scans,
            selection: selection,
            permissions: permissionsViewModel
        )
    }

    func makeReviewViewModel() -> ReviewViewModel {
        ReviewViewModel(
            selection: selection,
            thumbnails: thumbnails,
            executeCleanup: executeCleanup,
            getStorageSnapshot: getStorageSnapshot,
            scans: scans,
            results: results,
            router: router
        )
    }
}
