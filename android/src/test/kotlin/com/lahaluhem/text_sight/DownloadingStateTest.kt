package com.lahaluhem.text_sight

import com.google.android.gms.common.moduleinstall.ModuleInstallStatusUpdate
import com.lahaluhem.text_sight.readiness.downloadingState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * `downloadingState`: a Play Services progress update to the `{downloading, progress}` wire map.
 *
 * A real fetch never runs on an emulator, since the OCR module is always present, so the GMS value
 * type is mocked and the rows below stand in for what Play Services would report mid-download.
 */
@RunWith(ParameterizedRobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class DownloadingStateTest(
    // The runner reads this positionally for the row's display name, so no test body touches it.
    @Suppress("UnusedPrivateProperty") case: String,
    private val bytes: Pair<Long, Long>?,
    private val expectedProgress: Double?,
) {
    @Test
    fun `reports the download fraction`() {
        // Built before the update is stubbed: Mockito rejects a whenever() nested inside another.
        val progressInfo = bytes?.let { (downloaded, total) ->
            mock<ModuleInstallStatusUpdate.ProgressInfo>().also {
                whenever(it.bytesDownloaded).thenReturn(downloaded)
                whenever(it.totalBytesToDownload).thenReturn(total)
            }
        }
        val update = mock<ModuleInstallStatusUpdate>()
        whenever(update.progressInfo).thenReturn(progressInfo)

        val map = downloadingState(update)

        assertEquals("downloading", map["state"])
        if (expectedProgress == null) {
            assertNull(map["progress"])
        } else {
            assertEquals(expectedProgress, map["progress"] as Double, 1e-9)
        }
    }

    companion object {
        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "{0}")
        fun cases(): Collection<Array<Any?>> = listOf(
            arrayOf("byte counts report the fraction", 130L to 260L, 0.5),
            arrayOf("no progress info yet leaves it null", null, null),
            arrayOf("a zero total guards against dividing by zero", 0L to 0L, null),
        )
    }
}
