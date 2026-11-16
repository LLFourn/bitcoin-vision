import Foundation

/**
 * A transaction file comes from anywhere, and the app takes any file: the
 * person may pick a video. A PSBT is kilobytes; this is the point past which
 * the file is not one and is not worth holding in memory, where it would be
 * copied again to be read as base64.
 */
let PSBT_FILE_LIMIT = 8 * 1024 * 1024

/** What a file offered as a transaction came to. */
enum PsbtFile: Equatable {
    case bytes(Data)

    case tooLarge

    case unreadable
}

/**
 * The file at [url], bounded, and off Main: it can be in the cloud. A file
 * the system copied into the app's Inbox to hand it over ("Open in…") is
 * removed once read, whatever it held; nothing else of the app's would.
 */
func readPsbtFile(at url: URL, limit: Int = PSBT_FILE_LIMIT) -> PsbtFile {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    guard url.isFileURL else { return .unreadable }
    defer { removeInboxCopy(url) }
    guard let stream = InputStream(url: url) else { return .unreadable }
    stream.open()
    defer { stream.close() }
    if let bytes = readAtMost(input: stream, limit: limit) { return .bytes(bytes) }
    return stream.streamError == nil ? .tooLarge : .unreadable
}

/** Deletes [url] only if it lies in `inbox`, the app's own copy of a file handed to it. */
func removeInboxCopy(_ url: URL, inbox: URL? = documentsInbox()) {
    guard let inbox else { return }
    let parent = url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
    if parent.path == inbox.resolvingSymlinksInPath().standardizedFileURL.path {
        try? FileManager.default.removeItem(at: url)
    }
}

func documentsInbox() -> URL? {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
        .appendingPathComponent("Inbox", isDirectory: true)
}
