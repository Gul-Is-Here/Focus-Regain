package com.focuseregain.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ScreenTimeHandler.CHANNEL)
            .setMethodCallHandler(ScreenTimeHandler(applicationContext))
        // Server pushes (focus nudge, daily summary, check-ins) land here, so users can mute them alone.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel("reminders", "Reminders", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Focus nudges, daily focus summaries and check-ins you turned on"
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
                }
            )
        }
    }

    // Restarts blocking if the system killed it, and starts it once permissions were granted in Settings.
    override fun onResume() {
        super.onResume()
        BlockerService.sync(this)
    }
}
