//
//  RootView.swift
//  AF Clean
//

import SwiftUI

struct RootView: View {

    let dependencies: AppDependencies

    var body: some View {
        Group {
            if dependencies.permissionsViewModel.shouldShowPriming {
                PermissionPrimerView(viewModel: dependencies.permissionsViewModel)
                    .transition(.opacity)
            } else {
                main
            }
        }
        .animation(.easeInOut(duration: 0.25), value: dependencies.permissionsViewModel.shouldShowPriming)
    }

    private var main: some View {
        NavigationStack(path: Bindable(dependencies.router).path) {
            DashboardView(viewModel: dependencies.makeDashboardViewModel())
                .navigationDestination(for: AppRouter.Route.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRouter.Route) -> some View {
        switch route {
        case .category(let category):
            switch category {
            case .similarPhotos:
                SimilarPhotosView(viewModel: dependencies.makeSimilarPhotosViewModel())
            case .screenshots:
                ScreenshotsView(viewModel: dependencies.makeScreenshotsViewModel())
            case .largeVideos:
                LargeVideosView(
                    viewModel: dependencies.makeLargeVideosViewModel(),
                    playerItems: dependencies.videoPlayback
                )
            case .duplicateContacts:
                DuplicateContactsView(viewModel: dependencies.makeDuplicateContactsViewModel())
            }

        case .review:
            // Built in the next phase.
            AFEmptyState(
                systemImage: "checklist",
                title: "Review",
                message: "The review and delete step lands next."
            )
            .background(AFBackground())

        case .result:
            EmptyView()
        }
    }
}
