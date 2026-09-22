//
//  LargeVideosView.swift
//  AF Clean
//

import SwiftUI

struct LargeVideosView: View {

    @State var viewModel: LargeVideosViewModel
    let playerItems: VideoPlaybackRepositoryImpl

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
        .navigationTitle(CleanCategory.largeVideos.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.videos.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.areAllSelected ? "Deselect all" : "Select all") {
                        viewModel.toggleSelectAll()
                    }
                    .font(Theme.Typography.callout)
                }
            }
        }
        .sheet(item: $viewModel.previewingAsset) { asset in
            VideoPreviewSheet(
                asset: asset,
                viewModel: viewModel,
                playerItems: playerItems
            )
        }
        .onAppear { viewModel.onAppear() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .scanning(let progress):
            ScanningView(progress: progress, accent: CleanCategory.largeVideos.accent)

        case .failed(let message):
            AFEmptyState(systemImage: "exclamationmark.triangle", title: "Scan failed", message: message)

        case .idle, .ready, .blocked:
            if viewModel.videos.isEmpty {
                AFEmptyState(
                    systemImage: "checkmark.circle",
                    title: "No videos",
                    message: CleanCategory.largeVideos.emptyMessage
                )
            } else {
                list
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.s) {
                HStack {
                    Text(viewModel.summary)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.top, Theme.Spacing.s)

                ForEach(viewModel.videos) { video in
                    VideoRow(
                        asset: video,
                        thumbnails: viewModel.thumbnails,
                        isSelected: viewModel.isSelected(video),
                        onToggle: { viewModel.toggle(video) },
                        onPreview: { viewModel.preview(video) }
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
    }
}

/// One video: thumbnail with duration, size, and a separate tap target for
/// previewing so "see it" and "select it" never get confused.
private struct VideoRow: View {

    let asset: MediaAsset
    let thumbnails: ThumbnailRepository
    let isSelected: Bool
    let onToggle: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button(action: onPreview) {
                AssetThumbnail(assetID: asset.id, repository: thumbnails, maxPixel: 240)
                    .frame(width: 84, height: 62)
                    .clipShape(.rect(cornerRadius: Theme.Radius.small))
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 3)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Text(Format.duration(asset.duration))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.55), in: .rect(cornerRadius: 4))
                            .padding(4)
                    }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(Format.bytes(asset.byteSize))
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("\(asset.pixelWidth)×\(asset.pixelHeight) · \(Format.duration(asset.duration))")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                if let date = asset.creationDate {
                    Text(Format.month(date))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }

            Spacer(minLength: 0)

            Button(action: onToggle) {
                SelectionCheck(isSelected: isSelected, size: 26)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.s)
        .background(
            isSelected ? Theme.Palette.surfaceElevated : Theme.Palette.surface,
            in: .rect(cornerRadius: Theme.Radius.medium)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .strokeBorder(
                    isSelected ? AnyShapeStyle(Theme.Gradients.accent) : AnyShapeStyle(Theme.Palette.stroke),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
        .contentShape(.rect)
    }
}
