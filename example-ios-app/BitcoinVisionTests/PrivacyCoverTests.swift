import UIKit
import XCTest
@testable import BitcoinVision

@MainActor
final class PrivacyCoverTests: XCTestCase {
    private func scene() throws -> UIWindowScene {
        try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    }

    private func covers(_ scene: UIWindowScene) -> [UIWindow] {
        scene.windows.filter { $0.windowLevel == PrivacyCover.level && !$0.isHidden }
    }

    func test_the_cover_is_a_window_above_anything_the_app_presents() throws {
        let scene = try scene()
        let cover = PrivacyCover()
        XCTAssertTrue(covers(scene).isEmpty)
        cover.cover(scene)
        let shown = covers(scene)
        XCTAssertEqual(1, shown.count)
        // Sheets and alerts are presented in the app's own window, below this one.
        XCTAssertGreaterThan(PrivacyCover.level, UIWindow.Level.alert)
        XCTAssertTrue(scene.windows.filter { $0 !== shown[0] }.allSatisfy { $0.windowLevel < PrivacyCover.level })
        XCTAssertFalse(shown[0].isKeyWindow)
        cover.uncover(scene)
        XCTAssertTrue(covers(scene).isEmpty)
    }

    func test_covering_twice_keeps_one_window_and_one_uncover_removes_it() throws {
        let scene = try scene()
        let cover = PrivacyCover()
        cover.cover(scene)
        cover.cover(scene)
        XCTAssertEqual(1, covers(scene).count)
        cover.uncover(scene)
        XCTAssertTrue(covers(scene).isEmpty)
    }

    func test_an_installed_cover_follows_the_scene_leaving_and_returning() throws {
        let scene = try scene()
        let cover = PrivacyCover()
        cover.install()
        NotificationCenter.default.post(name: UIScene.willDeactivateNotification, object: scene)
        XCTAssertEqual(1, covers(scene).count)
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        XCTAssertTrue(covers(scene).isEmpty)
    }
}
