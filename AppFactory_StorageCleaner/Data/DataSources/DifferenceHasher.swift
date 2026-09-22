//
//  DifferenceHasher.swift
//  AF Clean
//

import CoreGraphics

/// Produces the 64-bit perceptual fingerprint the similarity scan compares.
///
/// Uses a difference hash: shrink the image to 9x8 greyscale and record, for
/// each pair of horizontally adjacent pixels, whether the left is brighter than
/// the right. That is 8x8 = 64 comparisons.
///
/// The point of comparing neighbours rather than absolute values is that the
/// result survives the things that change between near-duplicate shots —
/// exposure, white balance, scale, re-compression — while still differing
/// sharply between unrelated images.
enum DifferenceHasher {

    private static let width = 9
    private static let height = 8

    static func hash(of image: CGImage) -> UInt64? {
        let count = width * height
        var pixels = [UInt8](repeating: 0, count: count)

        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let base = buffer.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                  )
            else { return false }

            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard drawn else { return nil }

        var hash: UInt64 = 0
        var bit: UInt64 = 0
        for row in 0..<height {
            let offset = row * width
            for column in 0..<(width - 1) {
                if pixels[offset + column] > pixels[offset + column + 1] {
                    hash |= (1 << bit)
                }
                bit += 1
            }
        }
        return hash
    }
}
