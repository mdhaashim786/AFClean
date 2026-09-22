//
//  Components.swift
//  AF Clean
//
//  Shared building blocks for the dark card-based layout.
//

import SwiftUI

// MARK: - Surfaces

/// Standard elevated card.
struct AFCard<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.l
    var cornerRadius: CGFloat = Theme.Radius.large
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Theme.Palette.stroke, lineWidth: 1)
            }
    }
}

// MARK: - Buttons

/// Primary call to action. Gradient when enabled, flat when not, so a disabled
/// "Delete" never looks tappable.
struct AFPrimaryButtonStyle: ButtonStyle {
    var tint: LinearGradient = Theme.Gradients.accent
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundStyle(isEnabled ? Color.black : Theme.Palette.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                if isEnabled {
                    tint
                } else {
                    Theme.Palette.surfaceElevated
                }
            }
            .clipShape(.rect(cornerRadius: Theme.Radius.medium))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AFSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.callout)
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, 10)
            .background(
                configuration.isPressed ? Theme.Palette.surfacePressed : Theme.Palette.surfaceElevated,
                in: .rect(cornerRadius: Theme.Radius.pill)
            )
    }
}

// MARK: - Selection

/// Checkmark shown over selectable thumbnails.
struct SelectionCheck: View {
    let isSelected: Bool
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? AnyShapeStyle(Theme.Gradients.accent) : AnyShapeStyle(Color.black.opacity(0.35)))
            Circle()
                .strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.85), lineWidth: 1.5)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

/// Small capsule label, e.g. the "Best" badge on a keeper photo.
struct AFBadge: View {
    let text: String
    var systemImage: String?
    var tint: AnyShapeStyle = AnyShapeStyle(Theme.Gradients.accent)
    var foreground: Color = .black

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(tint, in: .rect(cornerRadius: Theme.Radius.pill))
        .foregroundStyle(foreground)
    }
}

// MARK: - States

/// Used wherever a list has nothing to show — including the "permission
/// denied" case, which is why it takes an optional action.
struct AFEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Theme.Gradients.accent)
                .padding(.bottom, Theme.Spacing.xs)

            Text(title)
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.textPrimary)

            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(AFSecondaryButtonStyle())
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .frame(maxWidth: 320)
        .padding(Theme.Spacing.xl)
    }
}

// MARK: - Layout helpers

/// Section heading used above grids and lists.
struct AFSectionHeader: View {
    let title: String
    var subtitle: String?
    var trailing: AnyView?

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> some View = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            Spacer(minLength: Theme.Spacing.s)
            trailing
        }
    }
}

/// Full-bleed app background: near-black with a single soft glow at the top.
struct AFBackground: View {
    var body: some View {
        ZStack {
            Theme.Palette.canvas
            Theme.Gradients.canvasGlow
                .blendMode(.plusLighter)
                .opacity(0.5)
        }
        .ignoresSafeArea()
    }
}
