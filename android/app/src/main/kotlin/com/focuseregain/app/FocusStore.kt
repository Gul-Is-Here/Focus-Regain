package com.focuseregain.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

data class FocusSession(
    val startedAt: Long,
    val endsAt: Long,
    val packages: Set<String>,
    val strict: Boolean,
    /** Set once the session is over (equal to [endsAt] if it ran to the end). */
    val endedAt: Long? = null,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("startedAt", startedAt)
        .put("endsAt", endsAt)
        .put("packages", JSONArray(packages.toList()))
        .put("strict", strict)
        .put("endedAt", endedAt ?: JSONObject.NULL)

    companion object {
        fun fromJson(o: JSONObject): FocusSession {
            val pkgs = o.getJSONArray("packages")
            return FocusSession(
                startedAt = o.getLong("startedAt"),
                endsAt = o.getLong("endsAt"),
                packages = (0 until pkgs.length()).map { pkgs.getString(it) }.toSet(),
                strict = o.optBoolean("strict"),
                endedAt = if (o.isNull("endedAt")) null else o.getLong("endedAt"),
            )
        }
    }
}

/** The running focus session and past ones. Native, so a session outlives the Flutter UI. */
object FocusStore {
    private const val FILE = "focus"
    private const val KEY_ACTIVE = "active"
    private const val KEY_HISTORY = "history"
    private const val MAX_HISTORY = 200
    private const val DONE_CHANNEL = "focus_done"
    private const val DONE_NOTIFICATION_ID = 2

    private fun prefs(context: Context) = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    /** The running session, or null. A session past its end is recorded and cleared here. */
    fun active(context: Context, now: Long = System.currentTimeMillis()): FocusSession? {
        val raw = prefs(context).getString(KEY_ACTIVE, null) ?: return null
        val session = try {
            FocusSession.fromJson(JSONObject(raw))
        } catch (e: JSONException) {
            prefs(context).edit().remove(KEY_ACTIVE).apply()
            return null
        }
        if (now < session.endsAt) return session
        finish(context, session, session.endsAt)
        return null
    }

    /** Starts a session, or returns the one already running. */
    fun start(context: Context, minutes: Int, packages: Set<String>, strict: Boolean): FocusSession {
        active(context)?.let { return it }
        val now = System.currentTimeMillis()
        val session = FocusSession(now, now + minutes * 60_000L, packages, strict)
        prefs(context).edit().putString(KEY_ACTIVE, session.toJson().toString()).apply()
        return session
    }

    /** Ends the running session early. False if strict mode forbids it. */
    fun stop(context: Context): Boolean {
        val session = active(context) ?: return true
        if (session.strict) return false
        finish(context, session, System.currentTimeMillis())
        return true
    }

    fun historyJson(context: Context): String = prefs(context).getString(KEY_HISTORY, null) ?: "[]"

    private fun finish(context: Context, session: FocusSession, endedAt: Long) {
        val history = try {
            JSONArray(historyJson(context))
        } catch (e: JSONException) {
            JSONArray()
        }
        history.put(session.copy(endedAt = endedAt).toJson())
        while (history.length() > MAX_HISTORY) history.remove(0)
        prefs(context).edit()
            .remove(KEY_ACTIVE)
            .putString(KEY_HISTORY, history.toString())
            .apply()
        if (endedAt >= session.endsAt) notifyDone(context, session)
    }

    private fun notifyDone(context: Context, session: FocusSession) {
        val manager = context.getSystemService(NotificationManager::class.java)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(DONE_CHANNEL, "Focus session done", NotificationManager.IMPORTANCE_DEFAULT)
            )
            Notification.Builder(context, DONE_CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val minutes = ((session.endsAt - session.startedAt) / 60_000L).toInt()
        val openApp = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
        )
        manager.notify(
            DONE_NOTIFICATION_ID,
            builder
                .setSmallIcon(R.drawable.ic_stat_focus)
                .setContentTitle("Focus session done")
                .setContentText("You stayed focused for ${BlockerService.formatMinutes(minutes)}.")
                .setContentIntent(openApp)
                .setAutoCancel(true)
                .build(),
        )
    }
}
