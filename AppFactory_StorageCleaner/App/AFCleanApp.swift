//
//  AFCleanApp.swift
//  AF Clean
//
//  On-device storage cleaner: find duplicate photos, screenshots,
//  large videos and duplicate contacts, then delete them after review.
//

import SwiftUI

@main
struct AFCleanApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
