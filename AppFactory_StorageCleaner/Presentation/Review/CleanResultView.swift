//
//  CleanResultView.swift
//  AF Clean
//

import SwiftUI

/// What actually happened. Reports the real outcome, including partial
/// failures, rather than assuming the plan succeeded.
struct CleanResultView: View {

    let outcome: CleanupOutcome
    let storage: StorageSnapshot
    let onDone: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            AFBackground()

            VStack(spacing: Theme.Spacing.xl) {
                Spacer(minLength: 0)

                badge

                VStack(spacing: Theme.Spacing.s) {
                    Text(title)
                        .font(Theme.Typography.hero)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Palette.textPrimary)

                    Text(subtitle)
                        .font(Theme.Typography.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                stats

                if outcome.deletedAssetCount > 0 {
                    reclaimNote
                }

                if outcome.hasFailures {
                    failures
                }

                Spacer(minLength: 0)

                Button("Done", action: onDone)
                    .buttonStyle(AFPrimaryButtonStyle())
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.l)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Pieces

    private var badge: some View {
        ZStack {
            Circle()
                .fill(Theme.Gradients.accentSoft)
                .frame(width: 120, height: 120)
            Image(systemName: outcome.didAnything ? "checkmark" : "hand.raised")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(Theme.Gradients.accent)
        }
        .scaleEffect(hasAppeared ? 1 : 0.6)
        .opacity(hasAppeared ? 1 : 0)
    }

    private var title: String {
        guard outcome.didAnything else { return "Nothing was removed" }
        return outcome.bytesFreed > 0 ? "Freed \(Format.bytes(outcome.bytesFreed))" : "Clean-up done"
    }

    private var subtitle: String {
        guard outcome.didAnything else {
            return outcome.wasCancelled
                ? "You cancelled, so everything is exactly as it was."
                : "Nothing changed."
        }
        if storage.isKnown {
            return "You now have \(Format.bytes(storage.freeBytes)) free on this iPhone."
        }
        return "Your selection has been removed."
    }

    /// iOS keeps deleted photos in Recently Deleted for 30 days, so the space
    /// is not handed back straight away. Saying "Freed 201 KB" and leaving it
    /// there would be a number the user cannot verify in Settings — this
    /// explains the gap instead of quietly hoping nobody checks.
    private var reclaimNote: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Palette.textTertiary)
            Text("iOS holds deleted photos in Recently Deleted for 30 days. The space is given back when you empty it in Photos, or when the 30 days are up.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Spacing.s)
    }

    private var stats: some View {
        VStack(spacing: Theme.Spacing.s) {
            if outcome.deletedAssetCount > 0 {
                StatRow(
                    systemImage: "photo.stack",
                    text: "\(Format.count(outcome.deletedAssetCount, singular: "photo or video", plural: "photos or videos")) moved to Recently Deleted",
                    tint: Theme.Palette.mint
                )
            }
            if outcome.mergedContactCount > 0 {
                StatRow(
                    systemImage: "arrow.triangle.merge",
                    text: "\(Format.count(outcome.mergedContactCount, singular: "duplicate contact")) merged",
                    tint: Theme.Palette.amber
                )
            }
            if outcome.deletedContactCount > 0 {
                StatRow(
                    systemImage: "person.badge.minus",
                    text: "\(Format.count(outcome.deletedContactCount, singular: "duplicate contact")) deleted",
                    tint: Theme.Palette.amber
                )
            }
        }
    }

    private var failures: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Some things did not go through", systemImage: "exclamationmark.triangle")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Palette.warning)
            ForEach(outcome.failures, id: \.self) { failure in
                Text(failure)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.warning.opacity(0.10), in: .rect(cornerRadius: Theme.Radius.medium))
    }
}

private struct StatRow: View {
    let systemImage: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: .rect(cornerRadius: Theme.Radius.small))
            Text(text)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.s)
    }
}
