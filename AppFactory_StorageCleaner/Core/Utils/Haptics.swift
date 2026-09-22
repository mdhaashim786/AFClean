//
//  Haptics.swift
//  AF Clean
//

import UIKit

/// Light physical feedback for selection and for committing a clean-up.
///
/// Deleting is irreversible enough to deserve a distinct signal from ordinary
/// tapping, so success and failure are separated rather than everything
/// buzzing the same way.
@MainActor
enum Haptics {

    private static let selection = UISelectionFeedbackGenerator()

    static func select() {
        selection.selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
