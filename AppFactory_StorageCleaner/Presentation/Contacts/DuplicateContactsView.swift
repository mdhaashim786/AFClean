//
//  DuplicateContactsView.swift
//  AF Clean
//

import SwiftUI

struct DuplicateContactsView: View {

    @State var viewModel: DuplicateContactsViewModel

    var body: some View {
        AccessGate(
            subject: .contacts,
            status: viewModel.permissions.contactsStatus,
            viewModel: viewModel.permissions
        ) {
            content
        }
        // Expand before the background: an empty state is small, and
        // without this the canvas only paints behind the text rather than
        // the whole screen.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AFBackground())
        .navigationTitle(CleanCategory.duplicateContacts.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.groups.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.decidedCount > 0 ? "Clear" : "Merge all") {
                        viewModel.decidedCount > 0 ? viewModel.clearAll() : viewModel.mergeAll()
                    }
                    .font(Theme.Typography.callout)
                }
            }
        }
        .onAppear { viewModel.onAppear() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .scanning(let progress):
            ScanningView(progress: progress, accent: CleanCategory.duplicateContacts.accent)

        case .failed(let message):
            AFEmptyState(systemImage: "exclamationmark.triangle", title: "Scan failed", message: message)

        case .idle, .ready, .blocked:
            if viewModel.groups.isEmpty {
                AFEmptyState(
                    systemImage: "checkmark.circle",
                    title: "No duplicates",
                    message: CleanCategory.duplicateContacts.emptyMessage
                )
            } else {
                list
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    HStack {
                        Text(viewModel.summary)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Spacer(minLength: 0)
                    }
                    Text("Merging keeps one card with everything from the others. Contacts are not recoverable afterwards, so nothing happens until you confirm.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, Theme.Spacing.s)

                ForEach(viewModel.groups) { group in
                    ContactGroupCard(
                        group: group,
                        action: viewModel.action(for: group),
                        onChoose: { viewModel.choose($0, for: group) }
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
    }
}

private struct ContactGroupCard: View {

    let group: ContactDuplicateGroup
    let action: CleanupPlan.ContactOperation.Action?
    let onChoose: (CleanupPlan.ContactOperation.Action) -> Void

    var body: some View {
        AFCard(padding: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                header

                VStack(spacing: Theme.Spacing.s) {
                    ForEach(group.contacts) { contact in
                        ContactRow(contact: contact, isKeeper: contact.id == group.keeperID)
                    }
                }

                if action == .merge {
                    mergePreview
                }

                actions
            }
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.keeper.displayName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("\(Format.count(group.count, singular: "card")) · \(group.reasonLabel)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    /// Shows exactly what the surviving card will hold, so "merge" is not a
    /// leap of faith.
    private var mergePreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Keeps everything", systemImage: "arrow.triangle.merge")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.mint)
            if !group.mergedPhoneNumbers.isEmpty {
                Text(group.mergedPhoneNumbers.joined(separator: ", "))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            if !group.mergedEmailAddresses.isEmpty {
                Text(group.mergedEmailAddresses.joined(separator: ", "))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.mint.opacity(0.08), in: .rect(cornerRadius: Theme.Radius.small))
    }

    private var actions: some View {
        HStack(spacing: Theme.Spacing.s) {
            ChoiceButton(
                title: "Merge",
                systemImage: "arrow.triangle.merge",
                tint: Theme.Palette.mint,
                isOn: action == .merge,
                action: { onChoose(.merge) }
            )
            ChoiceButton(
                title: "Delete extras",
                systemImage: "trash",
                tint: Theme.Palette.danger,
                isOn: action == .delete,
                action: { onChoose(.delete) }
            )
        }
    }
}

private struct ChoiceButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(Theme.Typography.callout)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isOn ? tint.opacity(0.18) : Theme.Palette.surfaceElevated,
                    in: .rect(cornerRadius: Theme.Radius.small)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .strokeBorder(isOn ? tint : .clear, lineWidth: 1.5)
                }
                .foregroundStyle(isOn ? tint : Theme.Palette.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

private struct ContactRow: View {
    let contact: ContactRecord
    let isKeeper: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ZStack {
                Circle()
                    .fill(isKeeper ? AnyShapeStyle(Theme.Gradients.accentSoft) : AnyShapeStyle(Theme.Palette.surfaceElevated))
                Text(contact.initials)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isKeeper ? Theme.Palette.mint : Theme.Palette.textSecondary)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(contact.displayName)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(contact.subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            Spacer(minLength: 0)

            if isKeeper {
                AFBadge(text: "KEEP", systemImage: "checkmark")
            }
        }
    }
}
