//
//  ScreenshotsView.swift
//  AF Clean
//

import SwiftUI

struct ScreenshotsView: View {

    @State var viewModel: ScreenshotsViewModel

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 6),
        count: 3
    )

    var body: some View {
        AccessGate(
            subject: .photos,
            status: viewModel.permissions.photoStatus,
            viewModel: viewModel.permissions
        ) {
            content
        }
        // Expand before the background: an empty state is small, and
        // without this the canvas only paints behind the text rather than
        // the whole screen.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AFBackground())
        .navigationTitle(CleanCategory.screenshots.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.screenshots.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.areAllSelected ? "Deselect all" : "Select all") {
                        viewModel.toggleSelectAll()
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
            ScanningView(progress: progress, accent: CleanCategory.screenshots.accent)

        case .failed(let message):
            AFEmptyState(systemImage: "exclamationmark.triangle", title: "Scan failed", message: message)

        case .idle, .ready, .blocked:
            if viewModel.screenshots.isEmpty {
                AFEmptyState(
                    systemImage: "checkmark.circle",
                    title: "No screenshots",
                    message: CleanCategory.screenshots.emptyMessage
                )
            } else {
                grid
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                HStack {
                    Text(viewModel.summary)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.top, Theme.Spacing.s)

                ForEach(viewModel.sections) { section in
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        AFSectionHeader(
                            title: section.title,
                            subtitle: "\(Format.count(section.assets.count, singular: "screenshot")) · \(Format.bytes(section.totalBytes))"
                        ) {
                            Button(viewModel.areAllSelected(in: section) ? "None" : "All") {
                                viewModel.toggleAll(in: section)
                            }
                            .buttonStyle(AFSecondaryButtonStyle())
                        }

                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(section.assets) { asset in
                                PhotoGridCell(
                                    asset: asset,
                                    thumbnails: viewModel.thumbnails,
                                    isSelected: viewModel.isSelected(asset),
                                    showsSize: true,
                                    onTap: { viewModel.toggle(asset) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
    }
}
