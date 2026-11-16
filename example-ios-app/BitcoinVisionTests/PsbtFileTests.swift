import XCTest
@testable import BitcoinVision

final class PsbtFileTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func file(_ name: String, _ bytes: Data, in directory: URL? = nil) throws -> URL {
        let url = (directory ?? folder).appendingPathComponent(name)
        try bytes.write(to: url)
        return url
    }

    func test_a_file_within_the_limit_is_read_whole_and_left_where_it_was() throws {
        let bytes = Data((0..<200).map { UInt8($0) })
        let url = try file("a.psbt", bytes)
        XCTAssertEqual(.bytes(bytes), readPsbtFile(at: url, limit: 200))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_a_file_past_the_limit_is_refused_rather_than_held() throws {
        let url = try file("video.mov", Data(count: 201))
        XCTAssertEqual(.tooLarge, readPsbtFile(at: url, limit: 200))
    }

    func test_a_file_that_is_not_there_or_not_a_file_is_unreadable() {
        XCTAssertEqual(.unreadable, readPsbtFile(at: folder.appendingPathComponent("missing.psbt")))
        XCTAssertEqual(.unreadable, readPsbtFile(at: URL(string: "https://example.com/a.psbt")!))
    }

    func test_the_inbox_copy_of_an_opened_file_is_removed_once_read_whatever_it_held() throws {
        let inbox = try XCTUnwrap(documentsInbox())
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let bytes = Data([0x70, 0x73, 0x62, 0x74, 0xFF])
        let opened = try file("\(UUID().uuidString).psbt", bytes, in: inbox)
        XCTAssertEqual(.bytes(bytes), readPsbtFile(at: opened))
        XCTAssertFalse(FileManager.default.fileExists(atPath: opened.path))

        let large = try file("\(UUID().uuidString).mov", Data(count: 9), in: inbox)
        XCTAssertEqual(.tooLarge, readPsbtFile(at: large, limit: 8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: large.path))
    }

    func test_only_a_file_directly_in_the_inbox_is_removed() throws {
        let inbox = folder.appendingPathComponent("Inbox", isDirectory: true)
        let nested = inbox.appendingPathComponent("deeper", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let outside = try file("keep.psbt", Data([1]))
        let below = try file("keep.psbt", Data([1]), in: nested)
        let inside = try file("drop.psbt", Data([1]), in: inbox)
        for url in [outside, below, inside] { removeInboxCopy(url, inbox: inbox) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: below.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: inside.path))
    }
}
