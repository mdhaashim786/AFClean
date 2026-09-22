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

    // MARK: - Repositories

    let permissions: PermissionRepository
    let deviceStorage: DeviceStorageRepository

    // MARK: - Use cases

    let requestAccess: RequestAccessUseCase
    let getStorageSnapshot: GetStorageSnapshotUseCase

    // MARK: - Shared app-scoped state

    let permissionsViewModel: PermissionsViewModel

    init(
        permissions: PermissionRepository = PermissionRepositoryImpl(),
        deviceStorage: DeviceStorageRepository = DeviceStorageRepositoryImpl()
    ) {
        self.permissions = permissions
        self.deviceStorage = deviceStorage

        let requestAccess = RequestAccessUseCase(permissions: permissions)
        self.requestAccess = requestAccess
        self.getStorageSnapshot = GetStorageSnapshotUseCase(repository: deviceStorage)

        self.permissionsViewModel = PermissionsViewModel(access: requestAccess)
    }
}
