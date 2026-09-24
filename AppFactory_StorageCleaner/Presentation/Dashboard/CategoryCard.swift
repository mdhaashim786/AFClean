//
//  CategoryCard.swift
//  AF Clean
//

import SwiftUI

/// One category tile on the dashboard: what it found, how much it can free,
/// and a strip of previews so the user can see what they are about to review.
///
/// Every card is pinned to the same aspect ratio. Letting each one size to its
/// own content made the grid ragged — a card with previews towered over one
/// saying "Nothing to clean", and the two columns never lined up. Fixing the
/// shape means the four tiles always read as one set, whatever they contain.
struct CategoryCard: View {

    let category: CleanCategory
    let state: ScanCoordinator.CategoryState
    let itemCount: Int
    let reclaimableBytes: Int64
    let previewAssetIDs: [String]
    let thumbnails: ThumbnailRepository
    let action: () -> Void

    /// Very slightly taller than square: enough room for a two-line title plus
    /// a preview strip without anything having to shrink.
    private static let aspect: CGFloat = 0.92
    private static let previewSize: CGFloat = 32

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                header
                title

                Spacer(minLength: Theme.Spacing.xs)

                detail
                previews
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.m)
            .aspectRatio(Self.aspect, contentMode: .fit)
            .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.large)
                    .strokeBorder(Theme.Palette.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: category.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(category.accent)
                .frame(width: 32, height: 32)
                .background(category.accent.opacity(0.14), in: .rect(cornerRadius: Theme.Radius.small))

            Spacer(minLength: 0)

            if state.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .tint(Theme.Palette.textSecondary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
    }

    private var title: some View {
        Text(category.title)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.Palette.textPrimary)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var detail: some View {
        switch state {
        case .blocked(let status):
            statusLine(
                status.needsSettings ? "Access off — tap to fix" : "Tap to allow",
                systemImage: "lock",
                tint: Theme.Palette.warning
            )

        case .failed:
            statusLine("Couldn't scan", systemImage: "exclamationmark.triangle", tint: Theme.Palette.danger)

        case .scanning(let progress):
            VStack(alignment: .leading, spacing: 5) {
                Text(progress.phase.label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
                if progress.total > 0 {
                    ProgressView(value: progress.fraction)
                        .tint(category.accent)
                }
            }

        case .idle:
            statusLine("Not scanned yet", systemImage: "clock", tint: Theme.Palette.textTertiary)

        case .ready:
            if itemCount == 0 {
                statusLine("Nothing to clean", systemImage: "checkmark.circle", tint: Theme.Palette.textSecondary)
            } else {
                // Count and size stack rather than sharing a line: on a narrow
                // card a single line wrapped mid-phrase.
                VStack(alignment: .leading, spacing: 1) {
                    Text(Format.count(itemCount, singular: category.itemNoun.singular, plural: category.itemNoun.plural))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if reclaimableBytes > 0 {
                        Text(Format.bytes(reclaimableBytes))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(category.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
        }
    }

    private func statusLine(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(Theme.Typography.caption)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    /// Always occupies the same height so the cards stay identical whether or
    /// not this category has anything to preview.
    private var previews: some View {
        HStack(spacing: 5) {
            ForEach(previewAssetIDs.prefix(3), id: \.self) { id in
                AssetThumbnail(assetID: id, repository: thumbnails, maxPixel: 160)
                    .frame(width: Self.previewSize, height: Self.previewSize)
                    .clipShape(.rect(cornerRadius: 7))
            }
            Spacer(minLength: 0)
        }
        .frame(height: Self.previewSize)
        .opacity(previewAssetIDs.isEmpty ? 0 : 1)
    }
}
