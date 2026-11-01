package com.focuseregain.app

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context

object UsageEventsReader {
    fun read(context: Context, from: Long, to: Long, types: Set<Int>): List<UsageEventRecord> {
        val events = context.getSystemService(UsageStatsManager::class.java).queryEvents(from, to)
        val event = UsageEvents.Event()
        val records = ArrayList<UsageEventRecord>()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType in types) {
                records.add(UsageEventRecord(event.packageName, event.className, event.eventType, event.timeStamp))
            }
        }
        return records
    }
}
