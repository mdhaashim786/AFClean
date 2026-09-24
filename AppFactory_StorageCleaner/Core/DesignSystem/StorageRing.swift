//
//  StorageRing.swift
//  AF Clean
//

import SwiftUI

/// The dashboard hero: a ring showing how full the device is, with the free
/// space in the middle.
struct StorageRing: View {

    let snapshot: StorageSnapshot
    /// Space AF Clean believes it can recover, drawn as a lighter arc just
    /// inside the used arc so the user can see the win against the whole.
    var reclaimableBytes: Int64 = 0
    var diameter: CGFloat = 200

    @State private var animatedFraction: Double = 0

    private var lineWidth: CGFloat { diameter * 0.085 }

    /// Below this the arc is shorter than its own rounded line cap and renders
    /// as a stray dot on the ring, which reads as a rendering glitch rather
    /// than information. A few hundred megabytes against a 128 GB device is
    /// well under it, so the arc is simply omitted.
    private static let minimumVisibleFraction = 0.015

    private var reclaimableFraction: Double {
        guard snapshot.isKnown, reclaimableBytes > 0 else { return 0 }
        let fraction = min(snapshot.usedFraction, Double(reclaimableBytes) / Double(snapshot.totalBytes))
        return fraction >= Self.minimumVisibleFraction ? fraction : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Palette.surfaceElevated, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedFraction)
                .stroke(
                    Theme.Gradients.accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if reclaimableFraction > 0 {
                Circle()
                    .trim(from: 0, to: animatedFraction * (reclaimableFraction / max(snapshot.usedFraction, 0.0001)))
                    .stroke(
                        Theme.Palette.danger.opacity(0.9),
                        style: StrokeStyle(lineWidth: lineWidth * 0.34, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(lineWidth * 0.8)
            }

            centre
        }
        .frame(width: diameter, height: diameter)
        .onAppear { animate() }
        .onChange(of: snapshot) { _, _ in animate() }
    }

    private var centre: some View {
        VStack(spacing: 2) {
            if snapshot.isKnown {
                let parts = Format.bytesParts(snapshot.freeBytes)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(parts.value)
                        .font(.system(size: diameter * 0.2, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(parts.unit)
                        .font(.system(size: diameter * 0.095, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Text("free of \(Format.bytes(snapshot.totalBytes))")
                    .font(.system(size: diameter * 0.062, weight: .medium))
                    .foregroundStyle(Theme.Palette.textTertiary)
            } else {
                Text("—")
                    .font(.system(size: diameter * 0.2, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
    }

    private func animate() {
        withAnimation(.easeOut(duration: 0.9)) {
            animatedFraction = snapshot.usedFraction
        }
    }
}
