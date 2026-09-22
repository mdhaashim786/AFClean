//
//  AFLog.swift
//  AF Clean
//

import os

/// Scan diagnostics.
///
/// Scanning is the part of this app most likely to behave differently on a real
/// library than in testing — iCloud-only assets, odd formats, huge counts — so
/// it reports what it fetched, analysed and grouped rather than failing
/// silently into an empty result.
enum AFLog {
    static let scan = Logger(subsystem: "com.haashim.AFStorageCleaner", category: "scan")
    static let cleanup = Logger(subsystem: "com.haashim.AFStorageCleaner", category: "cleanup")
}
