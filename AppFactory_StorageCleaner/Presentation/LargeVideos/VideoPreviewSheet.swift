//
//  VideoPreviewSheet.swift
//  AF Clean
//

import AVKit
import SwiftUI

/// Plays a video so the user can check what it is before deciding.
struct VideoPreviewSheet: View {

    let asset: MediaAsset
    let viewModel: LargeVideosViewModel
    let playerItems: VideoPlaybackRepositoryImpl

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var needsDownload = false
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.canvas.ignoresSafeArea()

                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea(edges: .bottom)
                } else if isLoading {
                    ProgressView().tint(Theme.Palette.textSecondary)
                } else if needsDownload {
                    AFEmptyState(
                        systemImage: "icloud.and.arrow.down",
                        title: "Stored in iCloud",
                        message: "This video is not on your iPhone, so AF Clean cannot preview it without downloading. You can still select it for removal — its size is shown from the library."
                    )
                } else {
                    AFEmptyState(
                        systemImage: "exclamationmark.triangle",
                        title: "Cannot preview",
                        message: "This video could not be opened for playback."
                    )
                }
            }
            .navigationTitle(Format.bytes(asset.byteSize))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isSelected(asset) ? "Keep" : "Select") {
                        viewModel.toggle(asset)
                    }
                    .font(Theme.Typography.callout)
                }
            }
        }
        .task {
            let playable = await viewModel.playerItem(for: asset)
            isLoading = false
            guard let playable else { return }
            guard !playable.requiresDownload,
                  let item = playerItems.playerItem(for: playable.assetID)
            else {
                needsDownload = playable.requiresDownload
                return
            }
            player = AVPlayer(playerItem: item)
            player?.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
            playerItems.discard(assetID: asset.id)
        }
    }
}
