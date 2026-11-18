import XCTest
@testable import BitcoinVision

final class WalletNameTests: XCTestCase {
    func test_names_are_trimmed() {
        XCTAssertEqual("Travel wallet", normalizedWalletName(input: "  Travel wallet \n"))
    }

    func test_empty_and_control_character_names_are_rejected() {
        for name in ["", " \t\n", "bad\nname", "bad\tname", "bad\u{0000}name"] {
            XCTAssertNil(normalizedWalletName(input: name))
        }
    }

    func test_names_have_a_forty_code_point_limit() {
        XCTAssertEqual(String(repeating: "x", count: 40), normalizedWalletName(input: String(repeating: "x", count: 40)))
        XCTAssertNil(normalizedWalletName(input: String(repeating: "x", count: 41)))
    }

    @MainActor
    func test_a_name_from_an_abandoned_adding_never_reaches_the_next_wallet() {
        let nav = Navigator()
        nav.navigate(.add(name: "Travel"))
        XCTAssertEqual("Travel", newWalletName(chosen: nav.addingName, numbered: "Wallet 2"))
        // Backing out drops that entry; the next adding starts its own.
        nav.popBackStack()
        XCTAssertNil(nav.addRoute)
        nav.navigate(.add(name: nil))
        XCTAssertEqual("Wallet 2", newWalletName(chosen: nav.addingName, numbered: "Wallet 2"))
        nav.popBackStack()
        nav.navigate(.add(name: "Savings"))
        nav.navigate(.newBackup)
        XCTAssertEqual("Savings", newWalletName(chosen: nav.addingName, numbered: "Wallet 2"))
        XCTAssertEqual("Wallet 2", newWalletName(chosen: "  \t", numbered: "Wallet 2"))
    }

    func test_supplementary_characters_count_once() {
        let symbol = "\u{1F3D5}"
        XCTAssertEqual(String(repeating: symbol, count: 40), normalizedWalletName(input: String(repeating: symbol, count: 40)))
        XCTAssertNil(normalizedWalletName(input: String(repeating: symbol, count: 41)))
    }
}
