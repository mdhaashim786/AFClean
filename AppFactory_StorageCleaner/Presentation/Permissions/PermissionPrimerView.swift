//
//  PermissionPrimerView.swift
//  AF Clean
//

import SwiftUI

/// Shown once, before the system prompts.
///
/// The brief asks for Photos and Contacts access with a clear reason. iOS only
/// gives us one line in its own alert and only one chance to ask, so this
/// explains what we need and why first — including that nothing leaves the
/// device and nothing is deleted without approval.
struct PermissionPrimerView: View {

    let viewModel: PermissionsViewModel

    @State private var isRequesting = false

    var body: some View {
        ZStack {
            AFBackground()

            VStack(spacing: 0) {
                Spacer(minLength: Theme.Spacing.xl)

                header

                Spacer(minLength: Theme.Spacing.xl)

                VStack(spacing: Theme.Spacing.m) {
                    PermissionRow(
                        systemImage: "photo.stack",
                        title: "Photos",
                        detail: "So AF Clean can find duplicates, screenshots and large videos, and remove the ones you pick."
                    )
                    PermissionRow(
                        systemImage: "person.2",
                        title: "Contacts",
                        detail: "So AF Clean can spot duplicate cards you can merge. Optional — skip it and the rest still works."
                    )
                }

                Spacer(minLength: Theme.Spacing.xl)

                privacyNote

                VStack(spacing: Theme.Spacing.s) {
                    Button {
                        Task {
                            isRequesting = true
                            await viewModel.requestAccess()
                            isRequesting = false
                        }
                    } label: {
                        Text(isRequesting ? "Waiting…" : "Continue")
                    }
                    .buttonStyle(AFPrimaryButtonStyle())
                    .disabled(isRequesting)

                    Button("Not now") {
                        viewModel.skipPriming()
                    }
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.vertical, Theme.Spacing.xs)
                }
                .padding(.top, Theme.Spacing.l)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.l)
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.m) {
            ZStack {
                Circle()
                    .fill(Theme.Gradients.accentSoft)
                    .frame(width: 96, height: 96)
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Theme.Gradients.accent)
            }

            Text("Free up space on\nyour iPhone")
                .font(Theme.Typography.hero)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textPrimary)

            Text("AF Clean finds the duplicate photos, screenshots, big videos and repeated contacts that are quietly taking up room.")
                .font(Theme.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            Image(systemName: "lock.shield")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Palette.mint)
            Text("Everything is analysed on this iPhone. Nothing is uploaded, and nothing is deleted until you review it and approve.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.medium))
    }
}

private struct PermissionRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.Gradients.accent)
                .frame(width: 34, height: 34)
                .background(Theme.Palette.surfaceElevated, in: .rect(cornerRadius: Theme.Radius.small))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(detail)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.medium))
    }
}
