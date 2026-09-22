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

    // MARK: - Use cases

    let requestAccess: RequestAccessUseCase
    let getStorageSnapshot: GetStorageSnapshotUseCase
    let scanSimilarPhotos: ScanSimilarPhotosUseCase
    let fetchScreenshots: FetchScreenshotsUseCase
    let fetchLargeVideos: FetchLargeVideosUseCase
    let scanDuplicateContacts: ScanDuplicateContactsUseCase
    let executeCleanup: ExecuteCleanupUseCase

    // MARK: - Shared app-scoped state

    let permissionsViewModel: PermissionsViewModel

    init(permissions: PermissionRepository = PermissionRepositoryImpl(),
         deviceStorage: DeviceStorageRepository = DeviceStorageRepositoryImpl()) {

        self.permissions = permissions
        self.deviceStorage = deviceStorage

        let photoAssets = PhotoAssetRepositoryImpl(source: photoKit, cache: analysisCache)
        let thumbnails = ThumbnailRepositoryImpl(source: photoKit)
        let imageHashes = ImageHashRepositoryImpl(source: photoKit, cache: analysisCache)

        let contacts = ContactRepositoryImpl(source: contactStore)

        self.photoAssets = photoAssets
        self.thumbnails = thumbnails
        self.imageHashes = imageHashes
        self.contacts = contacts

        let requestAccess = RequestAccessUseCase(permissions: permissions)
        self.requestAccess = requestAccess
        self.getStorageSnapshot = GetStorageSnapshotUseCase(repository: deviceStorage)
        self.scanSimilarPhotos = ScanSimilarPhotosUseCase(photos: photoAssets, hashes: imageHashes)
        self.fetchScreenshots = FetchScreenshotsUseCase(photos: photoAssets)
        self.fetchLargeVideos = FetchLargeVideosUseCase(photos: photoAssets)
        self.scanDuplicateContacts = ScanDuplicateContactsUseCase(contacts: contacts)
        self.executeCleanup = ExecuteCleanupUseCase(photos: photoAssets, contacts: contacts)

        self.permissionsViewModel = PermissionsViewModel(access: requestAccess)
    }
}
