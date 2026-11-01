package com.focuseregain.app

data class UsageEventRecord(
    val packageName: String,
    val className: String?,
    val type: Int,
    val timestamp: Long,
)

/**
 * Turns raw activity events into foreground time per package, close to Android's own totals.
 *
 * Events carry no activity instance id (it's hidden API), so activities are matched by class
 * name; the rules below cover what that misses, as seen on a Pixel 7 Pro (Android 17).
 */
object UsageCalculator {
    // Same values as UsageEvents.Event.ACTIVITY_RESUMED / ACTIVITY_PAUSED (MOVE_TO_FOREGROUND / BACKGROUND before API 29).
    const val RESUMED = 1
    const val PAUSED = 2
    // ACTIVITY_STOPPED (API 29+). Newer Android sometimes goes resumed -> stopped with no pause,
    // so a stop also ends the visit; otherwise the app counts as open until now.
    const val STOPPED = 23
    // SCREEN_NON_INTERACTIVE (API 28+).
    const val SCREEN_OFF = 16

    /** The events [foregroundTimes] needs. */
    val EVENT_TYPES = setOf(RESUMED, PAUSED, STOPPED, SCREEN_OFF)

    /**
     * An activity paused and resumed again within this time is a new copy replacing the old one;
     * a stop that soon after belongs to the old copy and must not end the visit.
     */
    private const val REOPEN_MS = 2_000L

    fun foregroundTimes(events: List<UsageEventRecord>, from: Long, to: Long): Map<String, Long> {
        val resumedActivities = HashMap<String, MutableSet<String>>()
        val startedAt = HashMap<String, Long>()
        val seen = HashSet<String>()
        // Keyed by "package/activity".
        val pausedAt = HashMap<String, Long>()
        val reopenedAt = HashMap<String, Long>()
        val totals = HashMap<String, Long>()

        fun add(pkg: String, ms: Long) {
            if (ms > 0) totals[pkg] = (totals[pkg] ?: 0L) + ms
        }

        for (e in events.sortedBy { it.timestamp }) {
            val activity = e.className ?: ""
            val key = "${e.packageName}/$activity"
            when (e.type) {
                SCREEN_OFF -> {
                    // Nothing is in use with the screen off. Also caps a visit an unmatched event left open.
                    for ((pkg, open) in resumedActivities) {
                        if (open.isNotEmpty()) add(pkg, e.timestamp - startedAt.getValue(pkg))
                    }
                    resumedActivities.clear()
                }
                RESUMED -> {
                    if (pausedAt[key]?.let { e.timestamp - it <= REOPEN_MS } == true) reopenedAt[key] = e.timestamp
                    val open = resumedActivities.getOrPut(e.packageName) { mutableSetOf() }
                    if (open.isEmpty()) startedAt[e.packageName] = e.timestamp
                    open.add(activity)
                    seen.add(e.packageName)
                }
                PAUSED, STOPPED -> {
                    if (e.type == PAUSED) {
                        pausedAt[key] = e.timestamp
                    } else if (reopenedAt.remove(key)?.let { e.timestamp - it <= REOPEN_MS } == true) {
                        continue // The old copy's stop.
                    }
                    if (seen.add(e.packageName)) {
                        // First event closes it: the app was already open when the window started.
                        add(e.packageName, e.timestamp - from)
                    } else {
                        val open = resumedActivities[e.packageName] ?: continue
                        if (open.remove(activity) && open.isEmpty()) {
                            add(e.packageName, e.timestamp - startedAt.getValue(e.packageName))
                        }
                    }
                }
            }
        }
        // Still in the foreground at the end of the window.
        for ((pkg, open) in resumedActivities) {
            if (open.isNotEmpty()) add(pkg, to - startedAt.getValue(pkg))
        }
        return totals
    }
}
