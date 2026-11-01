package com.focuseregain.app

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Calendar

class WeeklyRecapTest {
    private fun at(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0): Long =
        Calendar.getInstance().apply {
            clear()
            set(year, month - 1, day, hour, minute)
        }.timeInMillis

    @Test
    fun nextRunIsTheComingMondayAtNine() {
        // 2026-11-04 is a Wednesday.
        assertEquals(at(2026, 11, 9, 9), WeeklyRecap.nextRun(at(2026, 11, 4, 15)))
        // Monday before 09:00 -> same day; at or after 09:00 -> a week later.
        assertEquals(at(2026, 11, 9, 9), WeeklyRecap.nextRun(at(2026, 11, 9, 8, 59)))
        assertEquals(at(2026, 11, 16, 9), WeeklyRecap.nextRun(at(2026, 11, 9, 9)))
        // Sunday night -> next morning.
        assertEquals(at(2026, 11, 9, 9), WeeklyRecap.nextRun(at(2026, 11, 8, 23)))
    }

    @Test
    fun summaryIgnoresDaysWithoutData() {
        val s = WeeklyRecap.summarize(listOf(0, 120, 200, 180, 0, 90, 300), targetMinutes = 180)
        assertEquals(RecapSummary(totalMinutes = 890, averageMinutes = 178, daysOnTarget = 3, daysWithData = 5), s)
    }
}
