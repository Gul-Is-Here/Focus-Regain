package com.focuseregain.app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

data class RecapSummary(val totalMinutes: Int, val averageMinutes: Int, val daysOnTarget: Int, val daysWithData: Int)

/** Monday 09:00 notification summing up last Monday-Sunday. */
object WeeklyRecap {
    private const val FILE = "recap"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_TARGET = "target_minutes"
    private const val CHANNEL = "weekly_recap"
    private const val NOTIFICATION_ID = 3
    private const val HOUR = 9

    fun configure(context: Context, enabled: Boolean, targetMinutes: Int) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_ENABLED, enabled)
            .putInt(KEY_TARGET, targetMinutes)
            .apply()
        schedule(context)
    }

    /** (Re)sets the alarm for the next Monday morning, or cancels it if the recap is off. */
    fun schedule(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val pending = PendingIntent.getBroadcast(
            context, 0, Intent(context, RecapReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        if (!context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, false)) {
            alarms.cancel(pending)
            return
        }
        // Inexact on purpose: exact alarms need a permission Play reserves for alarm apps.
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextRun(System.currentTimeMillis()), pending)
    }

    /** The next Monday at 09:00 local time strictly after [now]. */
    fun nextRun(now: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = now }
        val isoDay = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1 // Calendar: Sunday = 1
        cal.add(Calendar.DAY_OF_MONTH, (8 - isoDay) % 7)
        cal.set(Calendar.HOUR_OF_DAY, HOUR)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        if (cal.timeInMillis <= now) cal.add(Calendar.DAY_OF_MONTH, 7)
        return cal.timeInMillis
    }

    /** Days with no usage at all are treated as "no data" and left out of the average. */
    fun summarize(dailyMinutes: List<Int>, targetMinutes: Int): RecapSummary {
        val withData = dailyMinutes.filter { it > 0 }
        return RecapSummary(
            totalMinutes = withData.sum(),
            averageMinutes = if (withData.isEmpty()) 0 else withData.sum() / withData.size,
            daysOnTarget = withData.count { it <= targetMinutes },
            daysWithData = withData.size,
        )
    }

    fun post(context: Context) {
        val target = context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getInt(KEY_TARGET, 180)
        val today = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val days = (7 downTo 1).map { back ->
            val start = (today.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, -back) }
            val end = (start.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, 1) }
            (UsageTotals.forRange(context, start.timeInMillis, end.timeInMillis).values.sum() / 60_000L).toInt()
        }
        val summary = summarize(days, target)
        if (summary.daysWithData == 0) return

        val manager = context.getSystemService(NotificationManager::class.java)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Weekly recap", NotificationManager.IMPORTANCE_DEFAULT)
            )
            Notification.Builder(context, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val fmt = BlockerService::formatMinutes
        val text = "Daily average ${fmt(summary.averageMinutes)}. On target " +
            "(${fmt(target)} or less) ${summary.daysOnTarget} of ${summary.daysWithData} days."
        val openApp = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
        )
        manager.notify(
            NOTIFICATION_ID,
            builder
                .setSmallIcon(R.drawable.ic_stat_focus)
                .setContentTitle("Last week: ${fmt(summary.totalMinutes)} of screen time")
                .setContentText(text)
                .setStyle(Notification.BigTextStyle().bigText(text))
                .setContentIntent(openApp)
                .setAutoCancel(true)
                .build(),
        )
    }
}

class RecapReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Reading a week of events can take a moment, so finish off the main thread.
        val pending = goAsync()
        Thread {
            try {
                if (Permissions.hasUsageAccess(context) && Permissions.notificationsEnabled(context)) {
                    WeeklyRecap.post(context)
                }
            } finally {
                WeeklyRecap.schedule(context)
                pending.finish()
            }
        }.start()
    }
}
