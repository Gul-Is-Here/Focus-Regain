package com.focuseregain.app

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import android.telecom.TelecomManager

/** Apps that are never blocked, so the user can always call, change settings or get back to us. */
object ProtectedApps {
    fun get(context: Context): Set<String> = setOfNotNull(
        context.packageName,
        homePackage(context),
        context.getSystemService(TelecomManager::class.java)?.defaultDialerPackage,
        resolve(context, Intent(Settings.ACTION_SETTINGS)),
        "com.android.settings",
    )

    fun homePackage(context: Context): String? =
        resolve(context, Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME))

    private fun resolve(context: Context, intent: Intent): String? =
        context.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            ?.activityInfo?.packageName
}
