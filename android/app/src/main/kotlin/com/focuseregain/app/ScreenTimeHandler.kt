package com.focuseregain.app

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class ScreenTimeHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.focuseregain.app/screen_time"
        private const val ICON_SIZE_PX = 128
    }

    private val worker = Executors.newSingleThreadExecutor()
    private val mainThread = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasUsageAccess" -> result.success(Permissions.hasUsageAccess(context))
            "openUsageAccessSettings" -> openSettings(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS), result)
            "hasOverlayPermission" -> result.success(Permissions.canDrawOverlays(context))
            "canRequestOverlay" -> result.success(Permissions.canRequestOverlay(context))
            "mayNeedRestrictedSettings" -> result.success(Permissions.mayNeedRestrictedSettings(context))
            "openAppInfo" -> openSettings(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")),
                result,
            )
            "openOverlaySettings" -> openSettings(
                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}")),
                result,
            )
            "isIgnoringBatteryOptimizations" -> result.success(Permissions.isIgnoringBatteryOptimizations(context))
            "openBatteryOptimizationSettings" -> openSettings(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
                result,
            )
            "getUsage" -> {
                val from = call.argument<Number>("from")!!.toLong()
                val to = call.argument<Number>("to")!!.toLong()
                runInBackground(result) { getUsage(from, to) }
            }
            "getAppIcon" -> {
                val packageName = call.arguments as String
                runInBackground(result) { getAppIcon(packageName) }
            }
            "getInstalledApps" -> runInBackground(result) { getInstalledApps() }
            "getBlockingRules" -> result.success(BlockingStore.rulesJson(context))
            "setBlockingRules" -> {
                // Handled in call order on the main thread, so the last change always wins.
                BlockingStore.setRules(context, call.arguments as String)
                BlockerService.sync(context)
                result.success(null)
            }
            "getActiveFocus" -> result.success(FocusStore.active(context)?.toJson()?.toString())
            "startFocus" -> {
                val session = FocusStore.start(
                    context,
                    minutes = call.argument<Int>("minutes")!!,
                    packages = call.argument<List<String>>("packages")!!.toSet(),
                    strict = call.argument<Boolean>("strict")!!,
                )
                BlockerService.sync(context)
                result.success(session.toJson().toString())
            }
            "stopFocus" -> {
                val stopped = FocusStore.stop(context)
                BlockerService.sync(context)
                result.success(stopped)
            }
            "getFocusHistory" -> result.success(FocusStore.historyJson(context))
            "getInterceptionsToday" -> result.success(BlockingStore.interceptionsToday(context))
            "configureWeeklyRecap" -> {
                WeeklyRecap.configure(
                    context,
                    enabled = call.argument<Boolean>("enabled")!!,
                    targetMinutes = call.argument<Int>("targetMinutes")!!,
                )
                result.success(null)
            }
            "hasNotificationPermission" -> result.success(Permissions.notificationsEnabled(context))
            "openNotificationSettings" -> openSettings(
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                } else {
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
                },
                result,
            )
            else -> result.notImplemented()
        }
    }

    private fun openSettings(intent: Intent, result: MethodChannel.Result) {
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        result.success(null)
    }

    // Reading a day of events and drawing icons can take a while; keep it off the UI thread.
    private fun runInBackground(result: MethodChannel.Result, work: () -> Any?) {
        worker.execute {
            try {
                val value = work()
                mainThread.post { result.success(value) }
            } catch (e: Exception) {
                mainThread.post { result.error("screen_time_failed", e.message, null) }
            }
        }
    }

    private fun getUsage(from: Long, to: Long): List<Map<String, Any>> {
        val pm = context.packageManager
        return UsageTotals.forRange(context, from, to)
            .mapNotNull { (pkg, ms) ->
                val info = try {
                    pm.getApplicationInfo(pkg, 0)
                } catch (e: PackageManager.NameNotFoundException) {
                    return@mapNotNull null // uninstalled since
                }
                mapOf(
                    "packageName" to pkg,
                    "label" to pm.getApplicationLabel(info).toString(),
                    "foregroundMs" to ms,
                    // The category the app declares (Android 8+); -1 = none.
                    "category" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) info.category else -1,
                )
            }
            .sortedByDescending { it["foregroundMs"] as Long }
    }

    /** Launchable apps the user may block, sorted by name. Protected apps are left out. */
    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = context.packageManager
        val protected = ProtectedApps.get(context)
        return pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
            .map { it.activityInfo }
            .distinctBy { it.packageName }
            .filter { it.packageName !in protected }
            .map { it to it.loadLabel(pm).toString() }
            .sortedBy { it.second.lowercase() }
            .map { (info, label) ->
                val category = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) info.applicationInfo.category else -1
                mapOf("packageName" to info.packageName, "label" to label, "category" to category)
            }
    }

    private fun getAppIcon(packageName: String): ByteArray? {
        val drawable = try {
            context.packageManager.getApplicationIcon(packageName)
        } catch (e: PackageManager.NameNotFoundException) {
            return null
        }
        val bitmap = Bitmap.createBitmap(ICON_SIZE_PX, ICON_SIZE_PX, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, ICON_SIZE_PX, ICON_SIZE_PX)
        drawable.draw(Canvas(bitmap))
        return ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    }
}
