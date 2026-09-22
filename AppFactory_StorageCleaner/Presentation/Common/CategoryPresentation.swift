//
//  CategoryPresentation.swift
//  AF Clean
//

import SwiftUI

/// How each category is labelled and coloured.
///
/// Lives in Presentation, not the domain: what a category *is* belongs to the
/// domain, what it looks like does not.
extension CleanCategory {

    var title: String {
        switch self {
        case .similarPhotos: "Similar Photos"
        case .screenshots: "Screenshots"
        case .largeVideos: "Large Videos"
        case .duplicateContacts: "Duplicate Contacts"
        }
    }

    var shortTitle: String {
        switch self {
        case .similarPhotos: "Photos"
        case .screenshots: "Screenshots"
        case .largeVideos: "Videos"
        case .duplicateContacts: "Contacts"
        }
    }

    var systemImage: String {
        switch self {
        case .similarPhotos: "square.on.square"
        case .screenshots: "iphone.gen3"
        case .largeVideos: "film.stack"
        case .duplicateContacts: "person.2"
        }
    }

    var accent: Color {
        switch self {
        case .similarPhotos: Theme.Palette.mint
        case .screenshots: Theme.Palette.info
        case .largeVideos: Theme.Palette.violet
        case .duplicateContacts: Theme.Palette.amber
        }
    }

    var itemNoun: (singular: String, plural: String) {
        switch self {
        case .similarPhotos: ("photo", "photos")
        case .screenshots: ("screenshot", "screenshots")
        case .largeVideos: ("video", "videos")
        case .duplicateContacts: ("contact", "contacts")
        }
    }

    var emptyMessage: String {
        switch self {
        case .similarPhotos: "No duplicate or near-identical photos found. Your library is tidy."
        case .screenshots: "No screenshots in your library."
        case .largeVideos: "No videos in your library."
        case .duplicateContacts: "No duplicate contacts found."
        }
    }
}
