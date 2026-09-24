//
//  ReviewView.swift
//  AF Clean
//

import SwiftUI

/// The last screen before anything is removed.
///
/// Shows exactly what will go, grouped by category, with a running total of the
/// space it frees — and lets the user take anything back out before committing.
struct ReviewView: View {

    @State var viewModel: ReviewViewModel

    var body: some View {
        Group {
            if viewModel.isEmpty {
                AFEmptyState(
                    systemImage: "tray",
                    title: "Nothing selected",
                    message: "Pick the photos, videos or contacts you want to remove and they will show up here first."
                )
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AFBackground())
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Discard all", role: .destructive) {
                        viewModel.discardAll()
                    }
                    .font(Theme.Typography.callout)
                    .disabled(viewModel.isDeleting)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !viewModel.isEmpty {
                deleteBar
            }
        }
        .alert(
            viewModel.confirmTitle,
            isPresented: Binding(
                get: { viewModel.stage == .confirming },
                set: { if !$0 { viewModel.cancelConfirmation() } }
            )
        ) {
            Button("Cancel", role: .cancel) { viewModel.cancelConfirmation() }
            Button("Delete", role: .destructive) {
                Task { await viewModel.confirmDelete() }
            }
        } message: {
            Text(viewModel.confirmMessage)
        }
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                summary

                ForEach(viewModel.populatedCategories) { category in
                    if category == .duplicateContacts {
                        contactSection
                    } else {
                        mediaSection(category)
                    }
                }

                safetyNote
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
    }

    private var summary: some View {
        AFCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("About to remove")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text("\(viewModel.totalItemCount)")
                        .font(Theme.Typography.hero)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(viewModel.totalItemCount == 1 ? "item" : "items")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }

                if viewModel.totalBytes > 0 {
                    Text("Frees about \(Format.bytes(viewModel.totalBytes))")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Palette.mint)
                }
            }
        }
        .padding(.top, Theme.Spacing.s)
    }

    private func mediaSection(_ category: CleanCategory) -> some View {
        let assets = viewModel.assets(in: category)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            AFSectionHeader(
                title: category.title,
                subtitle: "\(Format.count(assets.count, singular: category.itemNoun.singular, plural: category.itemNoun.plural)) · \(Format.bytes(assets.totalBytes))"
            )

            ForEach(assets) { asset in
                ReviewRow(
                    asset: asset,
                    thumbnails: viewModel.thumbnails,
                    onRemove: { viewModel.remove(asset) }
                )
            }
        }
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            AFSectionHeader(
                title: CleanCategory.duplicateContacts.title,
                subtitle: Format.count(
                    viewModel.plan.contactRemovalCount,
                    singular: "duplicate"
                )
            )

            ForEach(viewModel.contactDecisions, id: \.group.id) { decision in
                ContactReviewRow(
                    decision: decision,
                    onRemove: { viewModel.removeContactDecision(decision) }
                )
            }
        }
    }

    /// States plainly what is and is not reversible, so the user's approval is
    /// actually informed.
    private var safetyNote: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label {
                Text("Photos and videos go to Recently Deleted, where iOS keeps them for 30 days.")
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(Theme.Palette.mint)
            }

            if viewModel.hasContactChanges {
                Label {
                    Text("Contact changes are permanent and cannot be undone.")
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Theme.Palette.warning)
                }
            }
        }
        .font(Theme.Typography.caption)
        .foregroundStyle(Theme.Palette.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.medium))
    }

    // MARK: - Delete bar

    private var deleteBar: some View {
        Button {
            viewModel.askForConfirmation()
        } label: {
            if viewModel.isDeleting {
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView().tint(.black)
                    Text("Deleting…")
                }
            } else {
                HStack {
                    Text("Delete \(Format.count(viewModel.totalItemCount, singular: "item"))")
                    if viewModel.totalBytes > 0 {
                        Spacer()
                        Text("Frees \(Format.bytes(viewModel.totalBytes))")
                    }
                }
                .padding(.horizontal, Theme.Spacing.s)
            }
        }
        .buttonStyle(AFPrimaryButtonStyle(tint: Theme.Gradients.danger))
        .disabled(viewModel.isDeleting)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Rows

private struct ReviewRow: View {
    let asset: MediaAsset
    let thumbnails: ThumbnailRepository
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            AssetThumbnail(assetID: asset.id, repository: thumbnails, maxPixel: 160)
                .frame(width: 52, height: 52)
                .clipShape(.rect(cornerRadius: Theme.Radius.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(Format.bytes(asset.byteSize))
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            Spacer(minLength: 0)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Keep this one")
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.medium))
    }

    private var subtitle: String {
        var parts = ["\(asset.pixelWidth)×\(asset.pixelHeight)"]
        if asset.isVideo { parts.append(Format.duration(asset.duration)) }
        if let date = asset.creationDate { parts.append(Format.month(date)) }
        return parts.joined(separator: " · ")
    }
}

private struct ContactReviewRow: View {
    let decision: BuildCleanupPlanUseCase.ContactDecision
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: decision.action == .merge ? "arrow.triangle.merge" : "trash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(decision.action == .merge ? Theme.Palette.mint : Theme.Palette.danger)
                .frame(width: 34, height: 34)
                .background(Theme.Palette.surfaceElevated, in: .rect(cornerRadius: Theme.Radius.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(decision.group.keeper.displayName)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(detail)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            Spacer(minLength: 0)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Leave this group alone")
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.medium))
    }

    private var detail: String {
        let count = decision.group.duplicates.count
        return decision.action == .merge
            ? "Merge \(Format.count(count, singular: "duplicate")) into this card"
            : "Delete \(Format.count(count, singular: "duplicate"))"
    }
}
