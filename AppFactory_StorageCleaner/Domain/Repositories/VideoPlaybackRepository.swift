//
//  VideoPlaybackRepository.swift
//  AF Clean
//

import Foundation

/// A video ready to play, described without naming AVFoundation so the domain
/// stays framework-free. The Data layer knows how to turn this back into a
/// player item.
struct PlayableVideo: Sendable, Equatable {
    let assetID: String
    /// True when the original only exists in iCloud and we chose not to
    /// download it, so the UI can explain why playback is unavailable.
    let requiresDownload: Bool
}

protocol VideoPlaybackRepository: Sendable {
    func playable(for assetID: String) async -> PlayableVideo?
}
