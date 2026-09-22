//
//  Formatters.swift
//  AF Clean
//

import Foundation

enum Format {

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return formatter
    }()

    /// "1.24 GB". Clamps negatives to zero so a stale size estimate can never
    /// render as "-3 MB" in the review screen.
    static func bytes(_ value: Int64) -> String {
        byteFormatter.string(fromByteCount: max(0, value))
    }

    /// Splits a byte count into value and unit so the dashboard can typeset
    /// them at different sizes.
    static func bytesParts(_ value: Int64) -> (value: String, unit: String) {
        let text = bytes(value)
        let pieces = text.split(separator: " ", maxSplits: 1)
        guard pieces.count == 2 else { return (text, "") }
        return (String(pieces[0]), String(pieces[1]))
    }

    /// "1:05" / "1:02:03" for video durations.
    static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    /// "1 photo" / "12 photos"
    static func count(_ value: Int, singular: String, plural: String? = nil) -> String {
        let noun = value == 1 ? singular : (plural ?? singular + "s")
        return "\(value) \(noun)"
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()

    static func month(_ date: Date) -> String {
        monthFormatter.string(from: date)
    }

    /// "2.4s" / "412ms" — used by the scan progress readout.
    static func elapsed(_ seconds: TimeInterval) -> String {
        seconds < 1
            ? String(format: "%.0fms", seconds * 1000)
            : String(format: "%.1fs", seconds)
    }
}
