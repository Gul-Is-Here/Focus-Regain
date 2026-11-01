package com.focuseregain.app

import android.content.Context
import java.util.Calendar
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

data class BlockSchedule(
    val name: String,
    /** ISO weekdays: 1 = Monday ... 7 = Sunday. */
    val days: Set<Int>,
    /** Minutes after midnight. If end <= start the window runs past midnight. */
    val startMinute: Int,
    val endMinute: Int,
    val packages: Set<String>,
)

data class BlockingRules(
    val alwaysBlocked: Set<String> = emptySet(),
    val dailyLimits: Map<String, Int> = emptyMap(),
    val schedules: List<BlockSchedule> = emptyList(),
    /** Mindful pause instead of a hard block. */
    val pauseStyle: Boolean = false,
) {
    val isEmpty: Boolean
        get() = alwaysBlocked.isEmpty() && dailyLimits.isEmpty() && schedules.all { it.packages.isEmpty() }

    companion object {
        /** Parses the JSON written by Dart's BlockingRules.toJson; anything unreadable means "no rules". */
        fun fromJson(json: String?): BlockingRules {
            if (json == null) return BlockingRules()
            return try {
                val o = JSONObject(json)
                val limits = o.optJSONObject("dailyLimits")
                val schedules = o.optJSONArray("schedules")
                BlockingRules(
                    alwaysBlocked = o.optJSONArray("alwaysBlocked").strings(),
                    dailyLimits = limits?.keys()?.asSequence()?.associateWith { limits.getInt(it) } ?: emptyMap(),
                    schedules = (0 until (schedules?.length() ?: 0)).map { i ->
                        val s = schedules!!.getJSONObject(i)
                        BlockSchedule(
                            name = s.optString("name"),
                            days = s.optJSONArray("days").ints(),
                            startMinute = s.getInt("startMinute"),
                            endMinute = s.getInt("endMinute"),
                            packages = s.optJSONArray("packages").strings(),
                        )
                    },
                    pauseStyle = o.optString("style") == "pause",
                )
            } catch (e: JSONException) {
                BlockingRules()
            }
        }

        private fun JSONArray?.strings(): Set<String> =
            if (this == null) emptySet() else (0 until length()).map { getString(it) }.toSet()

        private fun JSONArray?.ints(): Set<Int> =
            if (this == null) emptySet() else (0 until length()).map { getInt(it) }.toSet()
    }
}

/** Rules and "open anyway" allowances. Kept natively so blocking works after a reboot, before Flutter starts. */
object BlockingStore {
    private const val FILE = "blocking"
    private const val KEY_RULES = "rules"
    private const val ALLOW_PREFIX = "allow_until_"
    private const val KEY_INTERCEPT_DAY = "intercept_day"
    private const val KEY_INTERCEPT_COUNT = "intercept_count"

    @Volatile private var cached: BlockingRules? = null

    private fun prefs(context: Context) = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun rulesJson(context: Context): String? = prefs(context).getString(KEY_RULES, null)

    // The service reads rules every poll, so parse once and keep the result.
    fun rules(context: Context): BlockingRules =
        cached ?: BlockingRules.fromJson(rulesJson(context)).also { cached = it }

    fun setRules(context: Context, json: String) {
        prefs(context).edit().putString(KEY_RULES, json).apply()
        cached = BlockingRules.fromJson(json)
    }

    fun allow(context: Context, packageName: String, untilMs: Long) {
        prefs(context).edit().putLong(ALLOW_PREFIX + packageName, untilMs).apply()
    }

    fun allowedUntil(context: Context, packageName: String): Long =
        prefs(context).getLong(ALLOW_PREFIX + packageName, 0L)

    /** Counts one block-screen appearance for today ("distractions stopped"). */
    fun recordInterception(context: Context, now: Long = System.currentTimeMillis()) {
        val today = startOfDay(now)
        val prefs = prefs(context)
        val count = if (prefs.getLong(KEY_INTERCEPT_DAY, 0L) == today) prefs.getInt(KEY_INTERCEPT_COUNT, 0) else 0
        prefs.edit().putLong(KEY_INTERCEPT_DAY, today).putInt(KEY_INTERCEPT_COUNT, count + 1).apply()
    }

    fun interceptionsToday(context: Context, now: Long = System.currentTimeMillis()): Int {
        val prefs = prefs(context)
        return if (prefs.getLong(KEY_INTERCEPT_DAY, 0L) == startOfDay(now)) prefs.getInt(KEY_INTERCEPT_COUNT, 0) else 0
    }
}

/** Local midnight at the start of the day containing [ms]. */
fun startOfDay(ms: Long): Long = Calendar.getInstance().apply {
    timeInMillis = ms
    set(Calendar.HOUR_OF_DAY, 0)
    set(Calendar.MINUTE, 0)
    set(Calendar.SECOND, 0)
    set(Calendar.MILLISECOND, 0)
}.timeInMillis
