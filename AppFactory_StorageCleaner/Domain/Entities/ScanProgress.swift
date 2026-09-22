//
//  ScanProgress.swift
//  AF Clean
//

import Foundation

/// Live progress for a running scan. Surfaced in the UI partly so the user is
/// not staring at a spinner, and partly because scan throughput is something
/// this app should be able to show off.
struct ScanProgress: Sendable, Equatable {

    enum Phase: String, Sendable {
        case idle
        case fetching
        case analysing
        case grouping
        case finished

        var label: String {
            switch self {
            case .idle: "Ready"
            case .fetching: "Reading library"
            case .analysing: "Analysing photos"
            case .grouping: "Grouping matches"
            case .finished: "Done"
            }
        }
    }

    var phase: Phase = .idle
    var processed: Int = 0
    var total: Int = 0
    var elapsed: TimeInterval = 0
    /// Items served from the persistent hash cache rather than re-analysed.
    var cacheHits: Int = 0

    static let idle = ScanProgress()

    var fraction: Double {
        total > 0 ? min(1, Double(processed) / Double(total)) : 0
    }

    var itemsPerSecond: Double {
        elapsed > 0.01 ? Double(processed) / elapsed : 0
    }

    var isRunning: Bool {
        phase != .idle && phase != .finished
    }
}
