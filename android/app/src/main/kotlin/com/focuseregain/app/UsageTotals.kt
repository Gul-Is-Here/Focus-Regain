package com.focuseregain.app

import android.content.Context

/** Foreground ms per app the way the dashboard counts it: launchable apps only, home screen left out. */
object UsageTotals {
    fun forRange(context: Context, from: Long, to: Long): Map<String, Long> {
        val records = UsageEventsReader.read(
            context, from, to, UsageCalculator.EVENT_TYPES,
        )
        val pm = context.packageManager
        // The home screen is always "open" between apps; Digital Wellbeing leaves it out too.
        val launcher = ProtectedApps.homePackage(context)
        return UsageCalculator.foregroundTimes(records, from, to)
            .filter { (pkg, _) -> pkg != launcher && pm.getLaunchIntentForPackage(pkg) != null }
    }
}
