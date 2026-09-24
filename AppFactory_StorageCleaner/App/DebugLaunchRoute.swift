//
//  DebugLaunchRoute.swift
//  AF Clean
//

#if DEBUG
import Foundation

/// Debug-build helper for jumping straight to a screen at launch.
///
/// The simulator cannot be driven by script without granting assistive access,
/// which makes verifying the deeper screens awkward. Passing a launch argument
/// gets there directly, and is also handy for capturing screenshots.
///
///     -afRoute similarPhotos | screenshots | largeVideos | duplicateContacts | review
///
/// Compiled out of release builds entirely.
enum DebugLaunchRoute {

    static func requested() -> AppRouter.Route? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-afRoute"),
              index + 1 < arguments.count
        else { return nil }

        switch arguments[index + 1] {
        case "similarPhotos": return .category(.similarPhotos)
        case "screenshots": return .category(.screenshots)
        case "largeVideos": return .category(.largeVideos)
        case "duplicateContacts": return .category(.duplicateContacts)
        case "review": return .review
        default: return nil
        }
    }

    /// Makes every photo report as a screenshot, so the Screenshots screen can
    /// be tested on the simulator.
    static var treatsPhotosAsScreenshots: Bool {
        ProcessInfo.processInfo.arguments.contains("-afPhotosAsScreenshots")
    }

    /// Mirrors what the user would do by hand — select every non-keeper — so
    /// the review screen has something real to show.
    static func shouldPreselect() -> Bool {
        ProcessInfo.processInfo.arguments.contains("-afPreselect")
    }
}
#endif
