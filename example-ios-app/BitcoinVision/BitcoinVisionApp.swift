import SwiftUI

@main
struct BitcoinVisionApp: App {
    /** A PSBT file the system handed in, until the app takes it. */
    @State private var incoming: PsbtFile?
    private let cover = PrivacyCover()

    /**
     * Release builds cover the window whenever the scene is not active; debug
     * builds stay visible so the simulator can screenshot the flow.
     */
    init() {
        #if !DEBUG
        cover.install()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppRoot(incoming: $incoming)
                // "Open in…" from Files, Mail or a wallet: a PSBT file, or text holding one.
                .onOpenURL { url in
                    Task {
                        let file = await Task.detached { readPsbtFile(at: url) }.value
                        if file != .unreadable { incoming = file }
                    }
                }
        }
    }
}
