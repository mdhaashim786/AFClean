//
//  DashboardView.swift
//  AF Clean
//

import SwiftUI

struct DashboardView: View {

    @State var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AFBackground()

                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        StorageRing(snapshot: viewModel.storage)
                            .padding(.top, Theme.Spacing.l)

                        if viewModel.permissions.isPhotoAccessLimited {
                            LimitedAccessBanner(viewModel: viewModel.permissions)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.xxl)
                }
                .refreshable { viewModel.refreshStorage() }
            }
            .navigationTitle("AF Clean")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear { viewModel.onAppear() }
    }
}
