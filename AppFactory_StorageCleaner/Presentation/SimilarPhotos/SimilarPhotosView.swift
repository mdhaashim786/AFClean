//
//  SimilarPhotosView.swift
//  AF Clean
//

import SwiftUI

struct SimilarPhotosView: View {

    @State var viewModel: SimilarPhotosViewModel

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
        .navigationTitle(CleanCategory.similarPhotos.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.groups.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.areAllOthersSelected ? "Deselect all" : "Select all") {
                        viewModel.toggleSelectAll()
                    }
                    .font(Theme.Typography.callout)
                }
            }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .scanning(let progress):
            ScanningView(progress: progress, accent: CleanCategory.similarPhotos.accent)

        case .failed(let message):
            AFEmptyState(
                systemImage: "exclamationmark.triangle",
                title: "Scan failed",
                message: message
            )

        case .idle, .ready, .blocked:
            if viewModel.groups.isEmpty {
                AFEmptyState(
                    systemImage: "checkmark.circle",
                    title: "All clear",
                    message: CleanCategory.similarPhotos.emptyMessage
                )
            } else {
                list
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.xl, pinnedViews: []) {
                summaryHeader

                ForEach(viewModel.groups) { group in
                    groupSection(group)
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
    }

    private var summaryHeader: some View {
        HStack {
            Text(viewModel.summary)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.top, Theme.Spacing.s)
    }

    private func groupSection(_ group: PhotoGroup) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            AFSectionHeader(
                title: group.reason.title,
                subtitle: "\(Format.count(group.count, singular: "photo")) · \(Format.bytes(group.reclaimableBytes)) can be freed"
            ) {
                Button(viewModel.areAllOthersSelected(in: group) ? "Keep all" : "Keep best") {
                    viewModel.toggleAllOthers(in: group)
                }
                .buttonStyle(AFSecondaryButtonStyle())
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(group.assets) { asset in
                    PhotoGridCell(
                        asset: asset,
                        thumbnails: viewModel.thumbnails,
                        isSelected: viewModel.isSelected(asset),
                        isBest: viewModel.isBest(asset, in: group),
                        onTap: { viewModel.toggle(asset, in: group) }
                    )
                }
            }
        }
    }
}

/// One selectable photo. Also used by the screenshots grid.
struct PhotoGridCell: View {

    let asset: MediaAsset
    let thumbnails: ThumbnailRepository
    let isSelected: Bool
    var isBest: Bool = false
    var showsSize: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            AssetThumbnail(assetID: asset.id, repository: thumbnails, maxPixel: 300)
                .aspectRatio(1, contentMode: .fill)
                .clipShape(.rect(cornerRadius: Theme.Radius.small))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .strokeBorder(
                            isSelected ? AnyShapeStyle(Theme.Gradients.accent) : AnyShapeStyle(Color.clear),
                            lineWidth: 2.5
                        )
                }
                .overlay(alignment: .topLeading) {
                    if isBest {
                        AFBadge(text: "BEST", systemImage: "star.fill")
                            .padding(5)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    SelectionCheck(isSelected: isSelected, size: 22)
                        .padding(5)
                }
                .overlay(alignment: .bottomLeading) {
                    if showsSize {
                        Text(Format.bytes(asset.byteSize))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.45), in: .rect(cornerRadius: 5))
                            .padding(5)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

/// Shared progress state for a category that is still scanning.
struct ScanningView: View {

    let progress: ScanProgress
    let accent: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            ProgressView(value: progress.total > 0 ? progress.fraction : nil)
                .progressViewStyle(.circular)
                .controlSize(.large)
                .tint(accent)

            Text(progress.phase.label)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Palette.textPrimary)

            if progress.total > 0 {
                Text("\(progress.processed) of \(progress.total)")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.textSecondary)

                // Surfacing throughput is partly reassurance and partly the
                // point: scan speed on a big library is a feature.
                if progress.itemsPerSecond > 0 {
                    Text("\(Int(progress.itemsPerSecond))/s · \(Format.elapsed(progress.elapsed))")
                        .font(Theme.Typography.mono)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                if progress.cacheHits > 0 {
                    Text("\(progress.cacheHits) already analysed")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xl)
    }
}
