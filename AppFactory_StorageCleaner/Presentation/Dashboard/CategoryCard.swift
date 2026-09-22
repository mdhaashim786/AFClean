//
//  CategoryCard.swift
//  AF Clean
//

import SwiftUI

/// One category tile on the dashboard: what it found, how much it can free,
/// and a strip of previews so the user can see what they are about to review.
struct CategoryCard: View {

    let category: CleanCategory
    let state: ScanCoordinator.CategoryState
    let itemCount: Int
    let reclaimableBytes: Int64
    let previewAssetIDs: [String]
    let thumbnails: ThumbnailRepository
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AFCard(padding: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    header
                    detail
                    if !previewAssetIDs.isEmpty {
                        previews
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var isDisabled: Bool {
        if case .blocked = state { return false }   // tapping explains how to fix it
        return state.isScanning && itemCount == 0
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: category.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(category.accent)
                .frame(width: 34, height: 34)
                .background(category.accent.opacity(0.14), in: .rect(cornerRadius: Theme.Radius.small))

            Text(category.title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Palette.textPrimary)

            Spacer(minLength: 0)

            if state.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .tint(Theme.Palette.textSecondary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch state {
        case .blocked(let status):
            Label(
                status.needsSettings ? "Access turned off — tap to fix" : "Tap to allow access",
                systemImage: "lock"
            )
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Palette.warning)

        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.danger)

        case .scanning(let progress):
            VStack(alignment: .leading, spacing: 6) {
                Text(progress.phase.label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                if progress.total > 0 {
                    ProgressView(value: progress.fraction)
                        .tint(category.accent)
                    Text("\(progress.processed) of \(progress.total)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }

        case .idle:
            Text("Not scanned yet")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textTertiary)

        case .ready:
            if itemCount == 0 {
                Label("Nothing to clean", systemImage: "checkmark.circle")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text(Format.count(itemCount, singular: category.itemNoun.singular, plural: category.itemNoun.plural))
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    if reclaimableBytes > 0 {
                        Text("· \(Format.bytes(reclaimableBytes))")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(category.accent)
                    }
                }
            }
        }
    }

    private var previews: some View {
        HStack(spacing: 6) {
            ForEach(previewAssetIDs, id: \.self) { id in
                AssetThumbnail(assetID: id, repository: thumbnails, maxPixel: 160)
                    .frame(width: 52, height: 52)
                    .clipShape(.rect(cornerRadius: Theme.Radius.small))
            }
            Spacer(minLength: 0)
        }
    }
}
