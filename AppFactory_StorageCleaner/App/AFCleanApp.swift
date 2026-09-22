//
//  AFCleanApp.swift
//  AF Clean
//
//  On-device storage cleaner: find duplicate photos, screenshots, large videos
//  and duplicate contacts, then delete them after review.
//

import SwiftUI

@main
struct AFCleanApp: App {

    @State private var dependencies = AppDependencies()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .preferredColorScheme(.dark)
                .tint(Theme.Palette.mint)
                .onChange(of: scenePhase) { _, phase in
                    // The user can revoke or widen access in Settings while we
                    // are backgrounded, so never trust a cached status.
                    if phase == .active {
                        dependencies.permissionsViewModel.refresh()
                    }
                }
        }
    }
}
