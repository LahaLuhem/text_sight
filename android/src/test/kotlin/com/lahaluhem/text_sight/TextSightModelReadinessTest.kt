package com.lahaluhem.text_sight

import com.lahaluhem.text_sight.readiness.readyState
import com.lahaluhem.text_sight.readiness.unavailableState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The terminal readiness wire maps, which the Dart side decodes into a `ModelReady` or a
 * `ModelUnavailable`. The mid-download map lives in [DownloadingStateTest].
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class TextSightModelReadinessTest {
    // region ready / unavailable: the terminal wire maps.

    @Test
    fun `readyState is the ready wire map`() {
        assertEquals(mapOf("state" to "ready"), readyState())
    }

    @Test
    fun `unavailableState carries its reason tag and details`() {
        val map = unavailableState("playServicesUnavailable", "Play Services missing")

        assertEquals("unavailable", map["state"])
        assertEquals("playServicesUnavailable", map["reason"])
        assertEquals("Play Services missing", map["details"])
    }

    @Test
    fun `unavailableState allows null details`() {
        val map = unavailableState("downloadFailed", null)

        assertEquals("downloadFailed", map["reason"])
        assertNull(map["details"])
    }

    // endregion
}
