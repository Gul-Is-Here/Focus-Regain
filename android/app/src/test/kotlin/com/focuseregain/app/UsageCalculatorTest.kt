package com.focuseregain.app

import com.focuseregain.app.UsageCalculator.PAUSED
import com.focuseregain.app.UsageCalculator.RESUMED
import com.focuseregain.app.UsageCalculator.SCREEN_OFF
import com.focuseregain.app.UsageCalculator.STOPPED
import org.junit.Assert.assertEquals
import org.junit.Test

class UsageCalculatorTest {
    private fun ev(pkg: String, cls: String, type: Int, t: Long) = UsageEventRecord(pkg, cls, type, t)

    @Test
    fun simpleOpenAndClose() {
        val totals = UsageCalculator.foregroundTimes(
            listOf(ev("a", "Main", RESUMED, 100), ev("a", "Main", PAUSED, 400)), 0, 1000,
        )
        assertEquals(mapOf("a" to 300L), totals)
    }

    @Test
    fun switchingActivitiesInsideOneAppCountsOnce() {
        val totals = UsageCalculator.foregroundTimes(
            listOf(
                ev("a", "Main", RESUMED, 100),
                ev("a", "Detail", RESUMED, 200),
                ev("a", "Main", PAUSED, 210),
                ev("a", "Detail", PAUSED, 500),
            ),
            0, 1000,
        )
        assertEquals(mapOf("a" to 400L), totals)
    }

    @Test
    fun appOpenBeforeWindowAndStillOpenAtEnd() {
        val totals = UsageCalculator.foregroundTimes(
            listOf(ev("a", "Main", PAUSED, 50), ev("b", "Main", RESUMED, 900)), 0, 1000,
        )
        assertEquals(mapOf("a" to 50L, "b" to 100L), totals)
    }

    // Seen on a Pixel 7 Pro (Android 17): resumed -> stopped with no pause, and pause + stop pairs.
    @Test
    fun stopWithoutPauseEndsTheVisit() {
        val totals = UsageCalculator.foregroundTimes(
            listOf(
                ev("dialer", "Main", RESUMED, 100),
                ev("dialer", "Main", STOPPED, 103),
                ev("a", "Main", RESUMED, 200),
                ev("a", "Main", PAUSED, 300),
                ev("a", "Main", STOPPED, 300),
            ),
            0, 10_000,
        )
        assertEquals(mapOf("dialer" to 3L, "a" to 100L), totals)
    }

    // Same device: the old copy pauses, a new copy resumes, then the old copy's stop arrives.
    @Test
    fun lateStopOfAReopenedActivityDoesNotEndTheVisit() {
        val totals = UsageCalculator.foregroundTimes(
            listOf(
                ev("v", "Player", RESUMED, 100),
                ev("v", "Player", PAUSED, 200),
                ev("v", "Player", RESUMED, 200),
                ev("v", "Player", STOPPED, 200),
                ev("v", "Player", PAUSED, 900),
                ev("v", "Player", STOPPED, 901),
            ),
            0, 10_000,
        )
        assertEquals(mapOf("v" to 800L), totals)
    }

    // A dialog (permission, billing) pauses the activity, it resumes without a stop,
    // and much later it is stopped without a pause: that stop still ends the visit.
    @Test
    fun stopLongAfterAPauseAndResumeEndsTheVisit() {
        val totals = UsageCalculator.foregroundTimes(
            listOf(
                ev("v", "Main", RESUMED, 100),
                ev("v", "Main", PAUSED, 200),
                ev("v", "Main", RESUMED, 201),
                ev("v", "Main", STOPPED, 5_000),
            ),
            0, 100_000,
        )
        assertEquals(mapOf("v" to 4_899L), totals)
    }

    @Test
    fun screenOffEndsEveryVisit() {
        val totals = UsageCalculator.foregroundTimes(
            listOf(
                ev("a", "Main", RESUMED, 100),
                ev("android", "", SCREEN_OFF, 500),
                ev("a", "Main", STOPPED, 520), // after the screen went off: nothing more
                ev("a", "Main", RESUMED, 1_000),
                ev("a", "Main", PAUSED, 1_300),
            ),
            0, 100_000,
        )
        assertEquals(mapOf("a" to 700L), totals)
    }
}
