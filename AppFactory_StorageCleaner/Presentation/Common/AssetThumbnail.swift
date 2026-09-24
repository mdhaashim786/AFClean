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
///
/// Layout note: the container decides the size and the image is laid over it,
/// never the other way round. A `.resizable()` image with `.fill` reports an
/// unbounded ideal size, so putting one directly in a `ZStack` lets it drag the
/// whole cell out to the photo's own aspect ratio — which is invisible with
/// square test images and tears the grid apart with tall ones like screenshots.
struct AssetThumbnail: View {

    let assetID: String
    let repository: ThumbnailRepository
    var maxPixel: Int = 240
    var contentMode: ContentMode = .fill

    @State private var image: CGImage?
    @State private var didFail = false

    var body: some View {
        // A plain Rectangle accepts whatever size it is offered, which makes it
        // the thing that defines the frame.
        Rectangle()
            .fill(Theme.Palette.surfaceElevated)
            .overlay {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else if didFail {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            // Crops the overflow a `.fill` image produces inside the frame.
            .clipped()
            .animation(.easeOut(duration: 0.18), value: image != nil)
            .task(id: assetID) {
                image = nil
                didFail = false
                let loaded = await repository.thumbnail(for: assetID, maxPixel: maxPixel)
                guard !Task.isCancelled else { return }
                image = loaded
                didFail = loaded == nil
            }
    }
}
