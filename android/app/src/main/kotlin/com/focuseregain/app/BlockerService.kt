package com.focuseregain.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import java.util.Calendar
import kotlin.math.ceil

/** Foreground service that covers blocked apps with [BlockActivity] while they are on screen. */
class BlockerService : Service() {
    companion object {
        private const val TAG = "BlockerService"
        private const val SERVICE_CHANNEL = "blocking"
        private const val WARNING_CHANNEL = "limit_warnings"
        private const val NOTIFICATION_ID = 1
        private const val POLL_MS = 700L
        private const val LOOKBACK_MS = 10_000L
        private const val USAGE_REFRESH_MS = 15_000L
        private const val RECOVER_MS = 2_000L
        private const val WARN_AT = 0.8

        /** Starts the service if a rule or focus session exists and the permissions are granted, else stops it. */
        fun sync(context: Context) {
            val intent = Intent(context, BlockerService::class.java)
            val hasWork = !BlockingStore.rules(context).isEmpty || FocusStore.active(context) != null
            val shouldRun = hasWork &&
                Permissions.hasUsageAccess(context) &&
                Permissions.canDrawOverlays(context)
            if (!shouldRun) {
                context.stopService(intent)
                return
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: IllegalStateException) {
                // Android 12+ refuses background starts outside the exempt cases; the next app open retries.
                Log.w(TAG, "Could not start blocking service", e)
            }
        }

        fun formatMinutes(minutes: Int): String {
            val h = minutes / 60
            val m = minutes % 60
            return when {
                h == 0 -> "$m min"
                m == 0 -> "$h h"
                else -> "$h h $m min"
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var protectedApps: Set<String>
    private var handledUpTo = 0L
    /** App currently on screen, as far as the latest app-opened event tells. */
    private var current: String? = null
    private var lastCoveredPkg: String? = null
    /** End time of the focus session the notification shows, so it is only rebuilt when that changes. */
    private var shownFocusEnd: Long? = null
    private var lastCoveredAt = 0L

    private var usageDay = 0L
    private var usageAt = 0L
    private var usageToday: Map<String, Long> = emptyMap()
    // shortcut: kept in memory, so a service restart can warn twice in a day; persist it if users notice.
    private val warned = HashSet<String>()

    private val poll = object : Runnable {
        override fun run() {
            checkForegroundApp()
            handler.postDelayed(this, POLL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        protectedApps = ProtectedApps.get(this)
        handledUpTo = System.currentTimeMillis()
        handler.post(poll)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Must be called promptly after startForegroundService, even if we stop right away.
        startInForeground()
        if (BlockingStore.rules(this).isEmpty && FocusStore.active(this) == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(poll)
        super.onDestroy()
    }

    private fun checkForegroundApp() {
        val now = System.currentTimeMillis()
        // Checked even with the screen off so a session ends (and says so) on time.
        val focus = FocusStore.active(this, now)
        if (focus?.endsAt != shownFocusEnd) {
            startInForeground()
            if (focus == null && BlockingStore.rules(this).isEmpty) {
                stopSelf()
                return
            }
        }
        if (!getSystemService(PowerManager::class.java).isInteractive) return
        val recent = UsageEventsReader.read(this, now - LOOKBACK_MS, now, setOf(UsageCalculator.RESUMED))
        val (opened, upTo) = BlockDecider.latestOpened(recent, handledUpTo)
        handledUpTo = upTo
        if (opened != null) current = opened

        val pkg = current ?: return
        if (pkg in protectedApps) return
        val rules = BlockingStore.rules(this)
        val cal = Calendar.getInstance()
        val isoDay = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1 // Calendar: Sunday = 1
        val minute = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

        val limit = rules.dailyLimits[pkg]
        val used = if (limit != null) usedMinutesToday(pkg, now) else 0
        if (limit != null) warnIfNearLimit(pkg, limit, used)

        val reason = BlockDecider.reason(pkg, rules, focus, isoDay, minute) { used } ?: return
        // Focus sessions are always a hard block: "open anyway" would defeat them.
        val pause = rules.pauseStyle && reason !is BlockReason.Focus
        if (pause && BlockingStore.allowedUntil(this, pkg) > now) return
        // The block screen takes a moment to report itself as open; don't relaunch it meanwhile.
        if (pkg == lastCoveredPkg && now - lastCoveredAt < RECOVER_MS) return
        lastCoveredPkg = pkg
        lastCoveredAt = now
        BlockingStore.recordInterception(this, now)
        startActivity(BlockActivity.intent(this, pkg, message(reason), pause))
    }

    private fun usedMinutesToday(pkg: String, now: Long): Int {
        val dayStart = startOfDay(now)
        if (dayStart != usageDay || now - usageAt > USAGE_REFRESH_MS) {
            val events = UsageEventsReader.read(
                this, dayStart, now, UsageCalculator.EVENT_TYPES,
            )
            usageToday = UsageCalculator.foregroundTimes(events, dayStart, now)
            usageDay = dayStart
            usageAt = now
        }
        return ((usageToday[pkg] ?: 0L) / 60_000L).toInt()
    }

    private fun message(reason: BlockReason): String = when (reason) {
        is BlockReason.Focus -> "You're in a focus session until ${clock(reason.endsAt)}."
        BlockReason.Always -> "You picked this app to pause."
        is BlockReason.Scheduled -> "Paused for ${reason.name} until %02d:%02d."
            .format(reason.endMinute / 60, reason.endMinute % 60)
        is BlockReason.LimitReached -> "You've used your ${formatMinutes(reason.limitMinutes)} for today."
    }

    private fun clock(ms: Long): String {
        val cal = Calendar.getInstance().apply { timeInMillis = ms }
        return "%02d:%02d".format(cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))
    }

    private fun warnIfNearLimit(pkg: String, limit: Int, used: Int) {
        if (used >= limit || used < ceil(limit * WARN_AT)) return
        if (!warned.add("$pkg@$usageDay")) return
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(WARNING_CHANNEL, "Limit warnings", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
        val label = try {
            packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0))
        } catch (e: PackageManager.NameNotFoundException) {
            return
        }
        val notification = notificationBuilder(WARNING_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_focus)
            .setContentTitle("${formatMinutes(limit - used)} left on $label")
            .setContentText("Your ${formatMinutes(limit)} daily limit is almost used up.")
            .setAutoCancel(true)
            .build()
        manager.notify(pkg.hashCode(), notification)
    }

    private fun notificationBuilder(channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channel)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

    private fun startInForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(SERVICE_CHANNEL, "Blocking", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val openApp = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
        )
        val focus = FocusStore.active(this)
        shownFocusEnd = focus?.endsAt
        val builder = notificationBuilder(SERVICE_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_focus)
            .setContentIntent(openApp)
            .setOngoing(true)
        if (focus != null) {
            // The system counts down by itself, so the notification never needs updating.
            builder
                .setContentTitle("Focus session")
                .setContentText("Apps you picked are blocked until ${clock(focus.endsAt)}.")
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
                .setWhen(focus.endsAt)
                .setShowWhen(true)
        } else {
            builder
                .setContentTitle("Blocking is on")
                .setContentText("Apps you picked get a pause screen.")
        }
        val notification = builder.build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }
}
