//
//  PermissionRepositoryImpl.swift
//  AF Clean
//

import Contacts
import Photos
import PhotosUI
import UIKit

/// Maps PhotoKit and Contacts authorisation onto the app's single
/// `AccessStatus` vocabulary, so everything above this deals with one enum
/// instead of two framework ones with different cases per OS version.
struct PermissionRepositoryImpl: PermissionRepository {

    var photoStatus: AccessStatus {
        Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    var contactsStatus: AccessStatus {
        Self.map(CNContactStore.authorizationStatus(for: .contacts))
    }

    // MARK: - Requesting

    func requestPhotoAccess() async -> AccessStatus {
        // We request .readWrite rather than .addOnly: deleting is the whole
        // point, and .readOnly cannot delete.
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return Self.map(status)
    }

    func requestContactsAccess() async -> AccessStatus {
        let store = CNContactStore()
        let granted: Bool = await withCheckedContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        // Re-read rather than trusting the boolean: on iOS 18 a "granted"
        // result can still mean limited access.
        let status = Self.map(CNContactStore.authorizationStatus(for: .contacts))
        if status == .notDetermined {
            return granted ? .authorized : .denied
        }
        return status
    }

    // MARK: - Recovery paths

    @MainActor
    func openSettings() async {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url)
        else { return }
        await UIApplication.shared.open(url)
    }

    @MainActor
    func presentLimitedLibraryPicker() async {
        guard let controller = TopViewControllerProvider.current() else { return }
        // The async overload returns the identifiers newly shared with us; we
        // only care that the picker has been dismissed before we re-read status.
        _ = await PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
    }

    // MARK: - Mapping

    private static func map(_ status: PHAuthorizationStatus) -> AccessStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .limited: .limited
        case .authorized: .authorized
        @unknown default: .notDetermined
        }
    }

    private static func map(_ status: CNAuthorizationStatus) -> AccessStatus {
        // `.limited` only exists from iOS 18, so it is checked separately
        // rather than as a switch case the iOS 17 build cannot name.
        if #available(iOS 18.0, *), status == .limited {
            return .limited
        }
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        default: return .notDetermined
        }
    }
}
