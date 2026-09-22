//
//  FeaturePrintComparator.swift
//  AF Clean
//

import CoreGraphics
import Vision

/// Vision-based similarity, used to sanity-check the cheap hash's weakest
/// matches.
///
/// A difference hash is fast but only describes coarse brightness structure, so
/// two unrelated images can occasionally land close together. A feature print
/// actually understands image content. It is far too slow to run over a whole
/// library, so it is only ever used to confirm a handful of already-suspected
/// pairs.
enum FeaturePrintComparator {

    /// Distances below this are treated as the same scene. Feature-print
    /// distance is unbounded, but near-duplicates sit well under 1.
    static let sameSceneThreshold: Float = 0.6

    static func featurePrint(for image: CGImage) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }

    static func distance(
        _ lhs: VNFeaturePrintObservation,
        _ rhs: VNFeaturePrintObservation
    ) -> Float? {
        var distance = Float(0)
        do {
            try lhs.computeDistance(&distance, to: rhs)
            return distance
        } catch {
            return nil
        }
    }
}
