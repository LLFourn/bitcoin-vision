import Foundation

/** The one name rule shared by input validation and persistence. */
func normalizedWalletName(input: String) -> String? {
    let name = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, name.unicodeScalars.count <= 40 else { return nil }
    // Java's ISO control characters: U+0000–U+001F and U+007F–U+009F.
    let control = name.unicodeScalars.contains { $0.value <= 0x1F || (0x7F...0x9F).contains($0.value) }
    return control ? nil : name
}

/** The name a wallet is saved under: the one chosen for this adding, when
 * there was one, else the numbered one. Only the adding's own route carries
 * the choice, so nothing from an earlier adding can reach it. */
func newWalletName(chosen: String?, numbered: String) -> String {
    chosen.flatMap { normalizedWalletName(input: $0) } ?? numbered
}
