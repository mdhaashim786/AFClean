//
//  DeviceStorageRepositoryImpl.swift
//  AF Clean
//

import Foundation

struct DeviceStorageRepositoryImpl: DeviceStorageRepository {

    func snapshot() -> StorageSnapshot {
        let url = URL(fileURLWithPath: NSHomeDirectory())

        guard let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]) else {
            return .unknown
        }

        let total = Int64(values.volumeTotalCapacity ?? 0)

        // `volumeAvailableCapacityForImportantUsage` is what Settings shows:
        // it counts space iOS would reclaim by purging caches. The plain
        // available capacity is the conservative fallback.
        let free = values.volumeAvailableCapacityForImportantUsage
            ?? Int64(values.volumeAvailableCapacity ?? 0)

        guard total > 0 else { return .unknown }
        return StorageSnapshot(totalBytes: total, freeBytes: max(0, min(free, total)))
    }
}
