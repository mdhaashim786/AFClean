//
//  AccessStatus.swift
//  AF Clean
//

import Foundation

/// Permission state, normalised across Photos and Contacts so the UI has one
/// shape to handle instead of two framework enums.
enum AccessStatus: Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    /// The user shared only a subset of their library (Photos), or a subset of
    /// their contacts (iOS 18+). We can still work — just over less data.
    case limited
    case authorized

    /// Can we read anything at all?
    var canRead: Bool {
        self == .authorized || self == .limited
    }

    /// The user has to go to Settings to change this.
    var needsSettings: Bool {
        self == .denied || self == .restricted
    }

    var shouldPrompt: Bool { self == .notDetermined }
}
