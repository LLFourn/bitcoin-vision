import SwiftUI
import UIKit

extension KeySource {
    func description() -> String {
        switch self {
        case .new: return "Made on this phone."
        case .writtenPhrase: return "Loaded from your written phrase."
        case let .strips(first, second):
            return "Loaded from share strips \(min(first, second)) and \(max(first, second))."
        }
    }
}

struct ConnectWalletScreen: View {
    let wallets: WalletsViewModel
    let id: String
    let onBack: () -> Void

    @State private var snackbar = SnackbarState()

    var body: some View {
        if let wallet = wallets.wallet(id: id) {
            WalletPage(title: "Connect to Sparrow", onBack: onBack, snackbar: snackbar) {
                Text(wallet.name).font(.titleLarge)
                Text("Scan this in Sparrow to watch the wallet and build transactions for this phone to sign.")
                    .foregroundStyle(Palette.onSurfaceVariant)
                StaticQr(text: wallet.descriptor, description: "Descriptor of \(wallet.name) as a QR code", tag: "descriptor-qr")
                    .frame(maxWidth: .infinity)
                WalletCard {
                    Text(wallet.descriptor)
                        .font(Typeface.mono(14, relativeTo: .callout))
                        .textSelection(.enabled)
                        .padding(16)
                        .accessibilityIdentifier("descriptor")
                }
                ShareLink(item: wallet.descriptor, subject: Text("Descriptor of \(wallet.name)")) {
                    Text("Share descriptor")
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("share-descriptor")
                Button("Copy descriptor") {
                    UIPasteboard.general.string = wallet.descriptor
                    snackbar.show("Descriptor copied")
                }
                .buttonStyle(.outlined)
                .accessibilityIdentifier("copy-descriptor")
            }
        } else {
            Color.clear.onAppear { onBack() }
        }
    }
}

struct KeyControlsScreen: View {
    let wallets: WalletsViewModel
    let id: String
    let onBack: () -> Void
    let onLoadKey: () -> Void

    @State private var confirmUnload = false

    var body: some View {
        if let wallet = wallets.wallet(id: id) {
            page(wallet)
                // Revealing is local to this visit, never restored from saved state.
                .onDisappear {
                    if wallets.revealed == id { wallets.revealed = nil }
                }
                .modifier(UnloadWarningDialog(
                    isPresented: $confirmUnload,
                    onKeep: { confirmUnload = false },
                    onUnload: {
                        wallets.unload(id: id)
                        confirmUnload = false
                    }
                ))
        } else {
            Color.clear.onAppear { onBack() }
        }
    }

    @ViewBuilder
    private func page(_ wallet: WalletRecord) -> some View {
        let key = wallets.key(id: id)
        WalletPage(title: "Secret words", onBack: onBack) {
            Text(wallet.name).font(.titleLarge)
            Text(wallet.fingerprint).font(Typeface.mono(14, relativeTo: .callout))
            Text(key == nil ? "Scan your words to send" : "Ready to send")
                .font(.titleMedium)
                .accessibilityIdentifier("key-status")
            if let key {
                Text(key.source.description()).foregroundStyle(Palette.onSurfaceVariant)
                if wallets.needsBackupWarning(id: id) {
                    Text("Not backed up on paper yet.").foregroundStyle(Palette.onSurfaceVariant)
                }
                let shown = wallets.revealed == id
                Button(shown ? "Hide my 12 words" : "Show my 12 words") {
                    wallets.revealed = shown ? nil : id
                }
                .buttonStyle(.outlined)
                .accessibilityIdentifier("show-phrase")
                if shown {
                    Text("Keep the screen private.").font(.labelLarge)
                    PhraseBody(words: key.words)
                }
                Button("Forget words now") {
                    if wallets.needsBackupWarning(id: id) { confirmUnload = true } else { wallets.unload(id: id) }
                }
                .buttonStyle(.secondary)
                .accessibilityIdentifier("unload")
            } else {
                Button("Scan your words", action: onLoadKey)
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("load-controls-key")
            }
        }
    }
}

struct PhraseBody: View {
    let words: [String]

    var body: some View {
        let half = (words.count + 1) / 2
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<2, id: \.self) { column in
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(stride(from: column * half, to: min((column + 1) * half, words.count), by: 1)), id: \.self) { i in
                        Text("\(i + 1). \(words[i])")
                            .font(Typeface.mono(22, relativeTo: .title3))
                            .accessibilityIdentifier("word-\(i + 1)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }
}

/** Addresses derived per step as the list nears its end. Numbered from 0, as Sparrow numbers them. */
private let ADDRESS_STEP: UInt32 = 20

/**
 * The receive addresses in order, more as the list is scrolled, from the
 * saved descriptor alone. The phone never sees the chain, so it cannot say
 * which are used: Sparrow can. Tapping one shows it as a QR code.
 */
struct ReceiveScreen: View {
    let wallets: WalletsViewModel
    let id: String
    let onBack: () -> Void

    @State private var addresses: [String] = []
    @State private var failed = false
    @State private var shown: Int?
    @State private var snackbar = SnackbarState()

    private func more(_ descriptor: String) {
        guard !failed else { return }
        do {
            addresses += try receiveAddresses(descriptor: descriptor, start: UInt32(addresses.count), count: ADDRESS_STEP)
        } catch {
            failed = true
        }
    }

    var body: some View {
        if let wallet = wallets.wallet(id: id) {
            page(wallet)
        } else {
            Color.clear.onAppear { onBack() }
        }
    }

    private func page(_ wallet: WalletRecord) -> some View {
        List {
            Text("Use a new address each time. Sparrow shows which ones have been used.")
                .foregroundStyle(Palette.onSurfaceVariant)
                .listRowSeparator(.hidden)
            if failed && addresses.isEmpty {
                Text(ERROR_MARK + "This wallet's addresses could not be worked out.")
                    .foregroundStyle(Palette.error)
            }
            ForEach(Array(addresses.enumerated()), id: \.offset) { i, address in
                Button { shown = i } label: {
                    HStack(spacing: 16) {
                        Text("\(i)").font(.titleMedium).frame(minWidth: 32, alignment: .leading)
                        Text(address).font(Typeface.mono(14, relativeTo: .callout))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("address-\(i)")
                .onAppear { if i >= addresses.count - 5 { more(wallet.descriptor) } }
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("addresses")
        .onAppear { if addresses.isEmpty { more(wallet.descriptor) } }
        .overlay(alignment: .bottom) { SnackbarHost(state: snackbar) }
        .background(Palette.surface.ignoresSafeArea())
        .foregroundStyle(Palette.onSurface)
        .navigationTitle("Receive")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { BackButton(action: onBack) }
        }
        .sheet(isPresented: Binding(get: { shown != nil }, set: { if !$0 { shown = nil } })) {
            if let index = shown, index < addresses.count {
                AddressSheet(index: index, address: addresses[index], walletName: wallet.name,
                             onCopied: { snackbar.show("Address copied") },
                             onClose: { shown = nil })
            }
        }
    }
}

private struct AddressSheet: View {
    let index: Int
    let address: String
    let walletName: String
    let onCopied: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                StaticQr(text: address, description: "Address \(index) as a QR code", tag: "address-qr")
                    .frame(maxWidth: .infinity)
                Text(address)
                    .font(Typeface.mono(14, relativeTo: .callout))
                    .textSelection(.enabled)
                    .accessibilityIdentifier("address")
                HStack(spacing: 8) {
                    Button("Copy") {
                        UIPasteboard.general.string = address
                        onCopied()
                    }
                    .buttonStyle(.outlined)
                    .accessibilityIdentifier("copy-address")
                    ShareLink(item: address, subject: Text("Address of \(walletName)")) {
                        Text("Share")
                    }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("share-address")
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Address \(index)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Close", action: onClose) }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
