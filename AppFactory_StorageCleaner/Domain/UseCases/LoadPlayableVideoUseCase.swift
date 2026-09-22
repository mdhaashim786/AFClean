//
//  LoadPlayableVideoUseCase.swift
//  AF Clean
//

import Foundation

struct LoadPlayableVideoUseCase: Sendable {
    private let repository: VideoPlaybackRepository

    init(repository: VideoPlaybackRepository) {
        self.repository = repository
    }

    func callAsFunction(assetID: String) async -> PlayableVideo? {
        await repository.playable(for: assetID)
    }
}
