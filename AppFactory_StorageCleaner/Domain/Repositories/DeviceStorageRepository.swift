//
//  DeviceStorageRepository.swift
//  AF Clean
//

import Foundation

protocol DeviceStorageRepository: Sendable {
    func snapshot() -> StorageSnapshot
}
