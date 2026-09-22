//
//  DashboardView.swift
//  AF Clean
//

import SwiftUI

struct DashboardView: View {

    @State var viewModel: DashboardViewModel

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.m),
        GridItem(.flexible(), spacing: Theme.Spacing.m)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                hero

                if viewModel.permissions.isPhotoAccessLimited {
                    LimitedAccessBanner(viewModel: viewModel.permissions)
                }

                if viewModel.hasStaleResults {
                    staleBanner
                }

                categories
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, viewModel.hasSelection ? 96 : Theme.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background(AFBackground())
        .navigationTitle("AF Clean")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.rescan()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isScanning)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.hasSelection {
                reviewBar
            }
        }
        .onAppear { viewModel.onAppear() }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: Theme.Spacing.m) {
            StorageRing(
                snapshot: viewModel.storage,
                reclaimableBytes: viewModel.totalReclaimableBytes
            )
            .padding(.top, Theme.Spacing.s)

            Text(viewModel.headline)
                .font(Theme.Typography.callout)
                .foregroundStyle(
                    viewModel.totalItemCount > 0 && !viewModel.isScanning
                        ? Theme.Palette.textPrimary
                        : Theme.Palette.textSecondary
                )
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: viewModel.headline)
        }
    }

    private var staleBanner: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(Theme.Palette.info)
            Text("Your library changed since this scan.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer(minLength: 0)
            Button("Rescan") { viewModel.rescan() }
                .buttonStyle(AFSecondaryButtonStyle())
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.info.opacity(0.10), in: .rect(cornerRadius: Theme.Radius.medium))
    }

    // MARK: - Categories

    private var categories: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
            ForEach(CleanCategory.allCases) { category in
                CategoryCard(
                    category: category,
                    state: viewModel.scans.state(for: category),
                    itemCount: viewModel.scans.itemCount(for: category),
                    reclaimableBytes: viewModel.scans.reclaimableBytes(for: category),
                    previewAssetIDs: viewModel.scans.previewAssetIDs(for: category, limit: 3),
                    thumbnails: viewModel.thumbnails,
                    action: { viewModel.open(category) }
                )
            }
        }
    }

    // MARK: - Review bar

    private var reviewBar: some View {
        VStack(spacing: 0) {
            Button {
                viewModel.openReview()
            } label: {
                HStack {
                    Text("Review \(Format.count(viewModel.selectedItemCount, singular: "item"))")
                    Spacer()
                    if viewModel.selectedBytes > 0 {
                        Text(Format.bytes(viewModel.selectedBytes))
                    }
                }
                .padding(.horizontal, Theme.Spacing.s)
            }
            .buttonStyle(AFPrimaryButtonStyle())
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
        }
        .background(.ultraThinMaterial)
    }
}
