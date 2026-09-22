//
//  Theme.swift
//  AF Clean
//
//  Design tokens for the app's dark visual language. The accent gradient is
//  lifted from the app icon (mint -> amber) so the product and its icon read
//  as one thing.
//

import SwiftUI

enum Theme {

    // MARK: - Palette

    enum Palette {
        /// App background. Near-black rather than pure black so elevated
        /// surfaces still have somewhere to go.
        static let canvas = Color(hex: 0x0A0B0D)
        static let surface = Color(hex: 0x16181C)
        static let surfaceElevated = Color(hex: 0x1F232A)
        static let surfacePressed = Color(hex: 0x272C34)

        static let stroke = Color.white.opacity(0.08)
        static let strokeStrong = Color.white.opacity(0.16)

        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.62)
        static let textTertiary = Color.white.opacity(0.38)

        /// Icon gradient endpoints.
        static let mint = Color(hex: 0x2AF2C2)
        static let amber = Color(hex: 0xFFCC00)

        static let danger = Color(hex: 0xFF5A5F)
        static let warning = Color(hex: 0xFFB020)
        static let info = Color(hex: 0x5AC8FA)
        static let violet = Color(hex: 0xA78BFA)
    }

    // MARK: - Gradients

    enum Gradients {
        static let accent = LinearGradient(
            colors: [Palette.mint, Palette.amber],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )

        static let accentSoft = LinearGradient(
            colors: [Palette.mint.opacity(0.22), Palette.amber.opacity(0.14)],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )

        /// Used behind the dashboard hero so the canvas is not flat.
        static let canvasGlow = RadialGradient(
            colors: [Palette.mint.opacity(0.18), .clear],
            center: .top,
            startRadius: 0,
            endRadius: 420
        )

        static let danger = LinearGradient(
            colors: [Palette.danger, Color(hex: 0xFF8A5B)],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

    // MARK: - Metrics

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 22
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Type

    enum Typography {
        static let hero = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 22, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 15, weight: .regular)
        static let callout = Font.system(size: 14, weight: .medium)
        static let caption = Font.system(size: 12, weight: .medium)
        static let mono = Font.system(size: 13, weight: .medium, design: .monospaced)
    }
}

extension Color {
    /// Convenience for the 0xRRGGBB literals used in the palette above.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
