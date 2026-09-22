//
//  DashboardViewModel.swift
//  AF Clean
//

import Observation

@MainActor
@Observable
final class DashboardViewModel {

    private(set) var storage: StorageSnapshot = .unknown

    let permissions: PermissionsViewModel

    private let getStorageSnapshot: GetStorageSnapshotUseCase

    init(
        getStorageSnapshot: GetStorageSnapshotUseCase,
        permissions: PermissionsViewModel
    ) {
        self.getStorageSnapshot = getStorageSnapshot
        self.permissions = permissions
    }

    // MARK: - Intents

    func onAppear() {
        refreshStorage()
    }

    func refreshStorage() {
        storage = getStorageSnapshot()
    }
}
