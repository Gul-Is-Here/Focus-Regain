package com.focuseregain.app

import com.focuseregain.app.UsageCalculator.RESUMED
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BlockDeciderTest {
    private fun opened(pkg: String, t: Long) = UsageEventRecord(pkg, "Main", RESUMED, t)
    private val mon = 1
    private val tue = 2
    private val sun = 7

    @Test
    fun latestOpenedIsTheNewestUnhandledEvent() {
        assertEquals("video" to 200L, BlockDecider.latestOpened(listOf(opened("maps", 100), opened("video", 200)), 0))
        assertEquals(null to 300L, BlockDecider.latestOpened(listOf(opened("video", 200)), 300))
    }

    @Test
    fun alwaysBlockedWins() {
        val rules = BlockingRules(alwaysBlocked = setOf("video"), dailyLimits = mapOf("video" to 30))
        assertEquals(BlockReason.Always, BlockDecider.reason("video", rules, null, mon, 600) { 0 })
    }

    @Test
    fun limitBlocksOnlyOnceUsedUp() {
        val rules = BlockingRules(dailyLimits = mapOf("video" to 30))
        assertNull(BlockDecider.reason("video", rules, null, mon, 600) { 29 })
        assertEquals(BlockReason.LimitReached(30), BlockDecider.reason("video", rules, null, mon, 600) { 30 })
        // Apps without a limit never pay for a usage lookup.
        assertNull(BlockDecider.reason("maps", rules, null, mon, 600) { error("not needed") })
    }

    @Test
    fun scheduleBlocksInsideItsWindow() {
        val work = BlockSchedule("Work", setOf(mon), 9 * 60, 17 * 60, setOf("video"))
        val rules = BlockingRules(schedules = listOf(work))
        assertEquals(BlockReason.Scheduled("Work", 17 * 60), BlockDecider.reason("video", rules, null, mon, 9 * 60) { 0 })
        assertNull(BlockDecider.reason("video", rules, null, mon, 17 * 60) { 0 })
        assertNull(BlockDecider.reason("video", rules, null, tue, 10 * 60) { 0 })
    }

    @Test
    fun overnightScheduleCarriesIntoTheNextMorning() {
        val night = BlockSchedule("Bedtime", setOf(sun), 22 * 60, 7 * 60, setOf("video"))
        assertTrue(BlockDecider.isActive(night, sun, 23 * 60))
        assertTrue(BlockDecider.isActive(night, mon, 6 * 60)) // Sunday night's window, Monday morning
        assertFalse(BlockDecider.isActive(night, mon, 23 * 60))
        assertFalse(BlockDecider.isActive(night, sun, 6 * 60))
    }

    @Test
    fun focusSessionBlocksItsAppsFirst() {
        val focus = FocusSession(startedAt = 0, endsAt = 1_000, packages = setOf("video", "chat"), strict = false)
        val rules = BlockingRules(dailyLimits = mapOf("video" to 30))
        assertEquals(BlockReason.Focus(1_000), BlockDecider.reason("video", rules, focus, mon, 600) { 0 })
        assertEquals(BlockReason.Focus(1_000), BlockDecider.reason("chat", rules, focus, mon, 600) { 0 })
        assertNull(BlockDecider.reason("maps", rules, focus, mon, 600) { 0 })
    }
}
