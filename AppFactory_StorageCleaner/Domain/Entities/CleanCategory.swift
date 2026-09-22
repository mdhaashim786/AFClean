//
//  CleanCategory.swift
//  AF Clean
//

import Foundation

/// The four things AF Clean can clean. Presentation supplies the icon and
/// colour for each; the domain only cares about identity and behaviour.
enum CleanCategory: String, CaseIterable, Identifiable, Sendable {
    case similarPhotos
    case screenshots
    case largeVideos
    case duplicateContacts

    var id: String { rawValue }

    /// Contacts are edited through the Contacts store, not deleted from the
    /// photo library, and — unlike photos — cannot be recovered afterwards.
    var isMedia: Bool { self != .duplicateContacts }

    /// Whether finding items in this category needs real scanning work.
    /// Screenshots and videos come straight out of a PhotoKit fetch.
    var requiresAnalysis: Bool {
        self == .similarPhotos || self == .duplicateContacts
    }
}
