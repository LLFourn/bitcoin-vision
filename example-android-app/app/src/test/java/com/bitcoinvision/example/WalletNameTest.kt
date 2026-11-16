package com.bitcoinvision.example

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WalletNameTest {
    @Test
    fun names_are_trimmed() {
        assertEquals("Travel wallet", normalizedWalletName("  Travel wallet \n"))
    }

    @Test
    fun empty_and_control_character_names_are_rejected() {
        for (name in listOf("", " \t\n", "bad\nname", "bad\tname", "bad\u0000name")) {
            assertNull(normalizedWalletName(name))
        }
    }

    @Test
    fun names_have_a_forty_code_point_limit() {
        assertEquals("x".repeat(40), normalizedWalletName("x".repeat(40)))
        assertNull(normalizedWalletName("x".repeat(41)))
    }

    @Test
    fun a_chosen_name_rides_in_the_add_route_and_nothing_else_carries_it() {
        // The name is held by the add route's own back stack entry: leaving
        // adding drops it, so it cannot reach a wallet added later.
        assertEquals("add", addWalletRoute(null))
        assertEquals("add", addWalletRoute("  \t"))
        val name = "Travel & savings \uD83C\uDFD5 50%"
        val route = addWalletRoute(name)
        val encoded = route.removePrefix("add?name=")
        assertTrue(encoded.none { it == ' ' || it == '&' || it == '?' })
        assertEquals(name, java.net.URLDecoder.decode(encoded, "UTF-8"))
    }

    /** The name Navigation hands an adding's screens, read from its route. */
    private fun nameIn(route: String): String? =
        route.substringAfter("add?name=", "").takeIf { it.isNotEmpty() }
            ?.let { java.net.URLDecoder.decode(it, "UTF-8") }

    @Test
    fun a_name_from_an_abandoned_adding_never_reaches_the_next_wallet() {
        val abandoned = addWalletRoute("Travel")
        assertEquals("Travel", newWalletName(nameIn(abandoned), "Wallet 2"))
        // Backing out drops that route; the next adding starts its own.
        val next = addWalletRoute(null)
        assertEquals("Wallet 2", newWalletName(nameIn(next), "Wallet 2"))
        val renamed = addWalletRoute("Savings")
        assertEquals("Savings", newWalletName(nameIn(renamed), "Wallet 2"))
    }

    @Test
    fun supplementary_characters_count_once() {
        val symbol = "\uD83C\uDFD5"
        assertEquals(symbol.repeat(40), normalizedWalletName(symbol.repeat(40)))
        assertNull(normalizedWalletName(symbol.repeat(41)))
    }
}
