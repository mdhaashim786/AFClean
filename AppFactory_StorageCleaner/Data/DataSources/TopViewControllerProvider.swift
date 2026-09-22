//
//  TopViewControllerProvider.swift
//  AF Clean
//

import UIKit

/// Finds the view controller to present system UI from.
///
/// Needed because PhotoKit's limited-library picker is UIKit-only and has no
/// SwiftUI equivalent. Confined to the Data layer so no SwiftUI view has to
/// know about UIWindowScene.
@MainActor
enum TopViewControllerProvider {

    static func current() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

        guard let root = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
                ?? scene?.windows.first?.rootViewController
        else { return nil }

        return topMost(from: root)
    }

    private static func topMost(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return topMost(from: presented)
        }
        if let navigation = controller as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topMost(from: visible)
        }
        if let tab = controller as? UITabBarController,
           let selected = tab.selectedViewController {
            return topMost(from: selected)
        }
        return controller
    }
}
