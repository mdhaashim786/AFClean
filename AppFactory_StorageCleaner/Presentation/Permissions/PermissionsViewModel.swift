//
//  PermissionsViewModel.swift
//  AF Clean
//

import Observation

/// Owns the app's permission state.
///
/// App-scoped rather than per-screen: several screens need to react to the same
/// statuses, and both can change while the app is backgrounded (the user can
/// revoke access in Settings at any time), so the state is refreshed whenever
/// the app becomes active.
@MainActor
@Observable
final class PermissionsViewModel {

    private(set) var photoStatus: AccessStatus
    private(set) var contactsStatus: AccessStatus
    /// True once the user has been past the priming screen, so we do not show
    /// it again after they have made a choice.
    private(set) var hasCompletedPriming: Bool

    private let access: RequestAccessUseCase

    init(access: RequestAccessUseCase) {
        self.access = access
        self.photoStatus = access.photoStatus
        self.contactsStatus = access.contactsStatus
        // If either prompt has already been answered, there is nothing left to
        // prime — go straight to the app.
        self.hasCompletedPriming = access.photoStatus != .notDetermined
    }

    // MARK: - Derived state

    /// Photos is the one permission the app cannot function without; contacts
    /// only disables its own category.
    var canUsePhotos: Bool { photoStatus.canRead }
    var canUseContacts: Bool { contactsStatus.canRead }

    var isPhotoAccessLimited: Bool { photoStatus == .limited }

    var shouldShowPriming: Bool { !hasCompletedPriming }

    // MARK: - Intents

    func refresh() {
        photoStatus = access.photoStatus
        contactsStatus = access.contactsStatus
    }

    /// Asks for both permissions in sequence, then leaves the priming screen
    /// regardless of the answers — a denial is a valid outcome that the rest of
    /// the app handles, not a reason to trap the user here.
    func requestAccess() async {
        if photoStatus.shouldPrompt {
            photoStatus = await access.requestPhotoAccess()
        }
        if contactsStatus.shouldPrompt {
            contactsStatus = await access.requestContactsAccess()
        }
        hasCompletedPriming = true
    }

    func skipPriming() {
        hasCompletedPriming = true
    }

    func requestPhotoAccessIfNeeded() async {
        guard photoStatus.shouldPrompt else { return }
        photoStatus = await access.requestPhotoAccess()
    }

    func requestContactsAccessIfNeeded() async {
        guard contactsStatus.shouldPrompt else { return }
        contactsStatus = await access.requestContactsAccess()
    }

    func openSettings() async {
        await access.openSettings()
    }

    /// Lets a user on limited access add more photos for AF Clean to see.
    func expandLimitedPhotoSelection() async {
        await access.expandLimitedPhotoSelection()
        refresh()
    }
}
