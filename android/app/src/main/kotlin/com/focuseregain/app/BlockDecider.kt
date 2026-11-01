package com.focuseregain.app

sealed class BlockReason {
    data class Focus(val endsAt: Long) : BlockReason()
    data object Always : BlockReason()
    data class Scheduled(val name: String, val endMinute: Int) : BlockReason()
    data class LimitReached(val limitMinutes: Int) : BlockReason()
}

object BlockDecider {
    /** Most recent app-opened event newer than [handledUpTo]: its package (or null) and the new [handledUpTo]. */
    fun latestOpened(events: List<UsageEventRecord>, handledUpTo: Long): Pair<String?, Long> {
        val latest = events
            .filter { it.type == UsageCalculator.RESUMED && it.timestamp > handledUpTo }
            .maxByOrNull { it.timestamp }
            ?: return null to handledUpTo
        return latest.packageName to latest.timestamp
    }

    /** Why [pkg] should be covered right now, or null. [usedMinutes] is only called for apps with a limit. */
    fun reason(
        pkg: String,
        rules: BlockingRules,
        focus: FocusSession?,
        isoDay: Int,
        minute: Int,
        usedMinutes: () -> Int,
    ): BlockReason? {
        if (focus != null && pkg in focus.packages) return BlockReason.Focus(focus.endsAt)
        if (pkg in rules.alwaysBlocked) return BlockReason.Always
        rules.schedules.firstOrNull { pkg in it.packages && isActive(it, isoDay, minute) }
            ?.let { return BlockReason.Scheduled(it.name, it.endMinute) }
        val limit = rules.dailyLimits[pkg] ?: return null
        return if (usedMinutes() >= limit) BlockReason.LimitReached(limit) else null
    }

    fun isActive(s: BlockSchedule, isoDay: Int, minute: Int): Boolean {
        if (s.startMinute == s.endMinute) return false
        if (s.startMinute < s.endMinute) {
            return isoDay in s.days && minute >= s.startMinute && minute < s.endMinute
        }
        // Overnight, e.g. 22:00-07:00: the early-morning part belongs to the previous day's schedule.
        val previousDay = if (isoDay == 1) 7 else isoDay - 1
        return (isoDay in s.days && minute >= s.startMinute) || (previousDay in s.days && minute < s.endMinute)
    }
}
