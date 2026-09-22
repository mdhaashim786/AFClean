//
//  RequestAccessUseCase.swift
//  AF Clean
//

import Foundation

/// Wraps permission prompting so view models never touch PhotoKit or Contacts.
struct RequestAccessUseCase: Sendable {

    private let permissions: PermissionRepository

    init(permissions: PermissionRepository) {
        self.permissions = permissions
    }

    var photoStatus: AccessStatus { permissions.photoStatus }
    var contactsStatus: AccessStatus { permissions.contactsStatus }

    func requestPhotoAccess() async -> AccessStatus {
        await permissions.requestPhotoAccess()
    }

    func requestContactsAccess() async -> AccessStatus {
        await permissions.requestContactsAccess()
    }

    func openSettings() async {
        await permissions.openSettings()
    }

    func expandLimitedPhotoSelection() async {
        await permissions.presentLimitedLibraryPicker()
    }
}
