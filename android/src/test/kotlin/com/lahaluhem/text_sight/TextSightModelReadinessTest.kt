package com.lahaluhem.text_sight

import com.google.android.gms.common.moduleinstall.ModuleInstallStatusUpdate
import com.lahaluhem.text_sight.readiness.downloadingState
import com.lahaluhem.text_sight.readiness.readyState
import com.lahaluhem.text_sight.readiness.unavailableState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Host-side unit tests for the readiness wire-map builders behind the model-readiness channel.
 *
 * The Play Services model download can't be triggered on an emulator — the OCR module is effectively
 * always present, so a real fetch never runs. These tests instead simulate what Play Services would
 * report mid-download — a [ModuleInstallStatusUpdate] carrying byte progress — and assert the
 * self-describing map the Dart side decodes into a `ModelDownloading` / `ModelReady` /
 * `ModelUnavailable`. No real ModuleInstallClient, Play Services, or network is involved; the GMS
 * value type is mocked, exactly as ML Kit's `Text` graph is in the camera tests.
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class TextSightModelReadinessTest {
    // region downloadingState — a Play Services progress update -> the {downloading, progress} map.

    @Test
    fun `downloadingState reports the byte fraction as progress`() {
        val update = updateWithProgress(bytesDownloaded = 130L, totalBytes = 260L)

        val map = downloadingState(update)

        assertEquals("downloading", map["state"])
        assertEquals(0.5, map["progress"] as Double, 1e-9)
    }

    @Test
    fun `downloadingState leaves progress null when no byte counts are reported yet`() {
        val update = mock<ModuleInstallStatusUpdate>()
        whenever(update.progressInfo).thenReturn(null)

        val map = downloadingState(update)

        assertEquals("downloading", map["state"])
        assertNull(map["progress"])
    }

    @Test
    fun `downloadingState guards a zero total against division by zero`() {
        val update = updateWithProgress(bytesDownloaded = 0L, totalBytes = 0L)

        val map = downloadingState(update)

        assertEquals("downloading", map["state"])
        assertNull(map["progress"])
    }

    // endregion

    // region ready / unavailable — the terminal wire maps.

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

    /** A mocked update whose progress info reports [bytesDownloaded] of [totalBytes]. */
    private fun updateWithProgress(
        bytesDownloaded: Long,
        totalBytes: Long,
    ): ModuleInstallStatusUpdate {
        val progressInfo = mock<ModuleInstallStatusUpdate.ProgressInfo>()
        whenever(progressInfo.bytesDownloaded).thenReturn(bytesDownloaded)
        whenever(progressInfo.totalBytesToDownload).thenReturn(totalBytes)

        val update = mock<ModuleInstallStatusUpdate>()
        whenever(update.progressInfo).thenReturn(progressInfo)

        return update
    }
}
