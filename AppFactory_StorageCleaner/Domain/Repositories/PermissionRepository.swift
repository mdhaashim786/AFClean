//
//  PermissionRepository.swift
//  AF Clean
//

import Foundation

protocol PermissionRepository: Sendable {

    var photoStatus: AccessStatus { get }
    var contactsStatus: AccessStatus { get }

    func requestPhotoAccess() async -> AccessStatus
    func requestContactsAccess() async -> AccessStatus

    /// Opens AF Clean's page in Settings, for users who previously denied us.
    func openSettings() async

    /// Shows the system picker for extending a limited photo selection.
    func presentLimitedLibraryPicker() async
}
