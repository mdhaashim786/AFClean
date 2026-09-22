//
//  GetStorageSnapshotUseCase.swift
//  AF Clean
//

import Foundation

struct GetStorageSnapshotUseCase: Sendable {
    private let repository: DeviceStorageRepository

    init(repository: DeviceStorageRepository) {
        self.repository = repository
    }

    func callAsFunction() -> StorageSnapshot {
        repository.snapshot()
    }
}
