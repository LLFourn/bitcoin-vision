package com.bitcoinvision.example

/** The one name rule shared by input validation and persistence. */
fun normalizedWalletName(input: String): String? {
    val name = input.trim()
    return name.takeIf {
        it.isNotEmpty() && it.codePointCount(0, it.length) <= 40 &&
            it.none { character -> Character.isISOControl(character) }
    }
}

/** The add-wallet route's pattern; the name chosen as adding begins rides in it. */
const val ADD_WALLET_ROUTE = "add?name={name}"

/** The add-wallet route carrying `name`, or none for the numbered name. The
 * name lives on that back stack entry, so leaving adding drops it. */
fun addWalletRoute(name: String?): String =
    normalizedWalletName(name ?: "")?.let { "add?name=${percentEncoded(it)}" } ?: "add"

/** Every byte but RFC 3986's unreserved ones as %XX, as Navigation decodes it. */
private fun percentEncoded(text: String): String = buildString {
    for (byte in text.toByteArray(Charsets.UTF_8)) {
        val c = byte.toInt() and 0xFF
        if (c.toChar().isLetterOrDigit() && c < 0x80 || c.toChar() in "-._~") append(c.toChar())
        else append('%').append("%02X".format(c))
    }
}
