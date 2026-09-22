//
//  AccessStateViews.swift
//  AF Clean
//
//  The two things a screen needs when permission is not full: a banner for
//  limited access, and a blocking state for denied access. Both always offer a
//  way forward so the user never hits a dead end.
//

import SwiftUI

/// Shown above content when the user shared only part of their library.
struct LimitedAccessBanner: View {

    let viewModel: PermissionsViewModel

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: "photo.badge.checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Palette.warning)

            VStack(alignment: .leading, spacing: 6) {
                Text("You've shared some photos")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("AF Clean can only look at the photos you selected. Add more to find everything worth cleaning.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Select more photos") {
                    Task { await viewModel.expandLimitedPhotoSelection() }
                }
                .buttonStyle(AFSecondaryButtonStyle())
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.warning.opacity(0.10), in: .rect(cornerRadius: Theme.Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .strokeBorder(Theme.Palette.warning.opacity(0.25), lineWidth: 1)
        }
    }
}

/// Full-screen state for a category the user has blocked.
struct AccessDeniedView: View {

    enum Subject {
        case photos
        case contacts

        var title: String {
            switch self {
            case .photos: "Photo access is off"
            case .contacts: "Contacts access is off"
            }
        }

        var message: String {
            switch self {
            case .photos:
                "AF Clean needs access to your photos to find what is taking up space. You can turn it on in Settings — nothing is uploaded and nothing is deleted without your approval."
            case .contacts:
                "AF Clean needs access to your contacts to find duplicate cards. You can turn it on in Settings. The other categories still work without it."
            }
        }

        var systemImage: String {
            switch self {
            case .photos: "photo.on.rectangle.angled"
            case .contacts: "person.crop.circle.badge.xmark"
            }
        }
    }

    let subject: Subject
    let status: AccessStatus
    let viewModel: PermissionsViewModel

    var body: some View {
        AFEmptyState(
            systemImage: subject.systemImage,
            title: status == .restricted ? "Access isn't available" : subject.title,
            message: status == .restricted
                ? "Access is restricted on this iPhone, possibly by Screen Time or a device policy."
                : subject.message,
            actionTitle: status == .restricted ? nil : "Open Settings",
            action: status == .restricted ? nil : { Task { await viewModel.openSettings() } }
        )
    }
}

/// Prompt shown when a category needs a permission the user has not been asked
/// for yet — for example opening Contacts after skipping the primer.
struct AccessRequestView: View {

    let subject: AccessDeniedView.Subject
    let viewModel: PermissionsViewModel

    var body: some View {
        AFEmptyState(
            systemImage: subject.systemImage,
            title: subject == .photos ? "Allow photo access" : "Allow contacts access",
            message: subject == .photos
                ? "AF Clean analyses your library on this iPhone to find duplicates, screenshots and large videos."
                : "AF Clean checks your contacts on this iPhone for duplicate cards you can merge.",
            actionTitle: "Continue",
            action: {
                Task {
                    switch subject {
                    case .photos: await viewModel.requestPhotoAccessIfNeeded()
                    case .contacts: await viewModel.requestContactsAccessIfNeeded()
                    }
                }
            }
        )
    }
}

/// Wraps content that needs a permission, swapping in the right state for
/// every case so no screen has to repeat this logic.
struct AccessGate<Content: View>: View {

    let subject: AccessDeniedView.Subject
    let status: AccessStatus
    let viewModel: PermissionsViewModel
    @ViewBuilder var content: Content

    var body: some View {
        switch status {
        case .authorized, .limited:
            content
        case .notDetermined:
            AccessRequestView(subject: subject, viewModel: viewModel)
        case .denied, .restricted:
            AccessDeniedView(subject: subject, status: status, viewModel: viewModel)
        }
    }
}
