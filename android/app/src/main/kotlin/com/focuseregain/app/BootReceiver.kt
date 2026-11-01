package com.focuseregain.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restarts blocking and the weekly-recap alarm after a reboot or an app update. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            BlockerService.sync(context)
            WeeklyRecap.schedule(context)
        }
    }
}
