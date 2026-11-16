import XCTest
@testable import BitcoinVision

/** Holds its first read until released, as native code that cannot be interrupted; reads nothing. */
private final class HeldReader: PhraseReader, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private let release = DispatchSemaphore(value: 0)

    var scans: Int { lock.withLock { count } }
    func finishFirst() { release.signal() }

    func scan(photo: ResolvedPhoto, observer: ScanProgressObserver) throws -> PhraseScan {
        let turn = lock.withLock { () -> Int in count += 1; return count }
        if turn == 1 { release.wait() }
        throw VisionError.Scan(detail: "nothing read")
    }
}

@MainActor
final class NewSeedViewModelTests: XCTestCase {
    private func until(_ what: String, _ met: () -> Bool) async throws {
        for _ in 0..<500 {
            if met() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("timed out waiting for \(what)")
    }

    private func shoot(_ model: NewSeedViewModel) {
        let metadata = CameraPhotoMetadata(rotationDegrees: 0, width: 1, height: 1, format: 256,
                                           displayRotationAtShutter: nil, sensorToDisplayDegreesAtShutter: nil)
        model.deliver(token: model.begin(), photo: PhotoInput.fromCamera(bytes: Data([1]), metadata: metadata))
    }

    func test_an_attempt_cancelled_while_waiting_for_the_scanner_never_reads() async throws {
        let reader = HeldReader()
        let model = NewSeedViewModel()
        model.reader = reader
        model.preparer = PhotoPreparer { ResolvedPhoto(source: $0, orientation: 1, rawWidth: 1, rawHeight: 1) }
        model.generate = { Array(repeating: "abandon", count: 11) + ["about"] }
        XCTAssertTrue(model.start())

        model.retake()
        shoot(model)
        try await until("the first read to start") { reader.scans == 1 }

        // The second attempt queues behind the read under way, and is cancelled there.
        model.retake()
        shoot(model)
        try await Task.sleep(nanoseconds: 200_000_000)
        model.retake()
        shoot(model)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(1, reader.scans)

        reader.finishFirst()
        try await until("the third attempt to end") { model.stage == .review }
        XCTAssertEqual(2, reader.scans)
    }
}
