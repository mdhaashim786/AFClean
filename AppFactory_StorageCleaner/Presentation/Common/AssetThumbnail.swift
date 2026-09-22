//
//  AssetThumbnail.swift
//  AF Clean
//

import SwiftUI

/// Loads and shows a photo library thumbnail by asset id.
///
/// Goes through `ThumbnailRepository`, so the view layer never sees PhotoKit.
/// Loads are cancelled when the view scrolls away, which matters in the grids
/// where hundreds of these exist at once.
struct AssetThumbnail: View {

    let assetID: String
    let repository: ThumbnailRepository
    var maxPixel: Int = 240
    var contentMode: ContentMode = .fill

    @State private var image: CGImage?
    @State private var didFail = false

    var body: some View {
        ZStack {
            Theme.Palette.surfaceElevated

            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else if didFail {
                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .clipped()
        .task(id: assetID) {
            image = nil
            didFail = false
            let loaded = await repository.thumbnail(for: assetID, maxPixel: maxPixel)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                image = loaded
                didFail = loaded == nil
            }
        }
    }
}
