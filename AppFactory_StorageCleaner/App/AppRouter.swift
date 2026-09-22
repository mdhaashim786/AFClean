//
//  AppRouter.swift
//  AF Clean
//

import Observation

/// Owns the navigation stack.
///
/// Routing is kept out of the views so that, for example, finishing a clean-up
/// can return the user to the dashboard without the review screen needing to
/// know where it sits in the stack.
@MainActor
@Observable
final class AppRouter {

    enum Route: Hashable {
        case category(CleanCategory)
        case review
        case result
    }

    var path: [Route] = []

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    /// After a clean-up, the result screen should be the only thing left on the
    /// stack — going "back" from it must not return to a review of items that
    /// no longer exist.
    func showResult() {
        path = [.result]
    }
}
