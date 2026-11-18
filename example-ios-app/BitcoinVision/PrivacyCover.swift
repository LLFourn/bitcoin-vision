import SwiftUI
import UIKit

/**
 * The phrase must never reach the app switcher's snapshot, and a word can be
 * on a sheet as well as on a page. UIKit presents sheets and alerts above the
 * root view, so nothing drawn inside the root view covers them; the cover is
 * its own window, above every presentation, for as long as the scene is not
 * active.
 */
@MainActor
final class PrivacyCover {
    /** Above alerts, which are the highest thing the app itself presents. */
    static let level = UIWindow.Level.alert + 1

    private var windows: [ObjectIdentifier: UIWindow] = [:]
    private var observers: [NSObjectProtocol] = []

    nonisolated init() {}

    /** Covers every scene from the moment it stops being active until it is active again. */
    func install() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIScene.willDeactivateNotification, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    if let scene = note.object as? UIWindowScene { self?.cover(scene) }
                }
            },
            center.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    if let scene = note.object as? UIWindowScene { self?.uncover(scene) }
                }
            },
            center.addObserver(forName: UIScene.didDisconnectNotification, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    if let scene = note.object as? UIWindowScene { self?.uncover(scene) }
                }
            },
        ]
    }

    func uninstall() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        for window in windows.values { window.isHidden = true }
        windows = [:]
    }

    func cover(_ scene: UIWindowScene) {
        let id = ObjectIdentifier(scene)
        if windows[id] != nil { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = Self.level
        let blank = UIViewController()
        blank.view.backgroundColor = UIColor(Palette.background)
        window.rootViewController = blank
        // Shown, never made key: the app's own window keeps its focus and its keyboard.
        window.isHidden = false
        windows[id] = window
    }

    func uncover(_ scene: UIWindowScene) {
        windows.removeValue(forKey: ObjectIdentifier(scene))?.isHidden = true
    }
}
