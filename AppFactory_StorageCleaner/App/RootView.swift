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
                DashboardView(
                    viewModel: DashboardViewModel(
                        getStorageSnapshot: dependencies.getStorageSnapshot,
                        permissions: dependencies.permissionsViewModel
                    )
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: dependencies.permissionsViewModel.shouldShowPriming)
    }
}
