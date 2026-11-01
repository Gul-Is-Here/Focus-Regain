package com.focuseregain.app

import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.ColorStateList
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.window.OnBackInvokedDispatcher

/**
 * Full-screen screen shown over a blocked app. Hard block: "Go back" only.
 * Mindful pause: a breathing circle, then "Open anyway" unlocks after a few seconds.
 * Colours match the Midnight Violet dark theme.
 */
class BlockActivity : Activity() {
    companion object {
        private const val EXTRA_PACKAGE = "package"
        private const val EXTRA_MESSAGE = "message"
        private const val EXTRA_PAUSE = "pause"
        private const val PAUSE_SECONDS = 5L
        private const val ALLOW_MINUTES = 5L

        private const val BACKGROUND = 0xFF273338.toInt()
        private const val TEXT = 0xFFEEF2EC.toInt()
        private const val MUTED = 0xFFB3C0B8.toInt()
        private const val PRIMARY = 0xFF9CB080.toInt()
        private const val ON_PRIMARY = 0xFF14200F.toInt()

        fun intent(context: Context, packageName: String, message: String, pause: Boolean): Intent =
            Intent(context, BlockActivity::class.java)
                .putExtra(EXTRA_PACKAGE, packageName)
                .putExtra(EXTRA_MESSAGE, message)
                .putExtra(EXTRA_PAUSE, pause)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    private val handler = Handler(Looper.getMainLooper())
    private var breathing: ValueAnimator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val pkg = intent.getStringExtra(EXTRA_PACKAGE)
        val pause = intent.getBooleanExtra(EXTRA_PAUSE, false)
        val dp = resources.displayMetrics.density
        val label = pkg?.let {
            try {
                packageManager.getApplicationLabel(packageManager.getApplicationInfo(it, 0))
            } catch (e: PackageManager.NameNotFoundException) {
                null
            }
        } ?: "This app"

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(BACKGROUND)
            val pad = (32 * dp).toInt()
            setPadding(pad, pad, pad, pad)
        }

        if (pause) {
            val circle = View(this).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(0x559CB080)
                    setStroke((2 * dp).toInt(), PRIMARY)
                }
                contentDescription = "Breathing circle"
            }
            root.addView(circle, LinearLayout.LayoutParams((160 * dp).toInt(), (160 * dp).toInt()))
            breathing = ObjectAnimator.ofPropertyValuesHolder(
                circle,
                PropertyValuesHolder.ofFloat(View.SCALE_X, 0.6f, 1f),
                PropertyValuesHolder.ofFloat(View.SCALE_Y, 0.6f, 1f),
            ).apply {
                duration = 4_000
                repeatMode = ValueAnimator.REVERSE
                repeatCount = ValueAnimator.INFINITE
                start()
            }
            root.addView(text("Breathe in… and out", 14f, MUTED, topDp = 24))
        }

        root.addView(text(if (pause) "Take a breath before $label" else "$label is paused", 26f, TEXT, topDp = 24))
        root.addView(
            text(intent.getStringExtra(EXTRA_MESSAGE) ?: "You picked this app to pause.", 16f, MUTED, topDp = 16)
        )

        root.addView(
            Button(this).apply {
                text = if (pause) "Close app" else "Go back"
                setTextColor(ON_PRIMARY)
                backgroundTintList = ColorStateList.valueOf(PRIMARY)
                setOnClickListener { goHome() }
            },
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                .apply { topMargin = (32 * dp).toInt() },
        )

        if (pause && pkg != null) {
            val openAnyway = Button(this, null, android.R.attr.borderlessButtonStyle).apply {
                text = "Open anyway"
                setTextColor(MUTED)
                isEnabled = false
                alpha = 0.4f
                setOnClickListener { openAnyway(pkg) }
            }
            root.addView(openAnyway)
            // The pause only works if it can't be skipped straight away.
            handler.postDelayed({
                openAnyway.isEnabled = true
                openAnyway.alpha = 1f
            }, PAUSE_SECONDS * 1_000)
            root.addView(text("Opens it for $ALLOW_MINUTES minutes.", 12f, MUTED, topDp = 4))
        }

        setContentView(root)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT) { goHome() }
        }
    }

    // A new block request (another app, or another reason) rebuilds the screen.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        recreate()
    }

    override fun onDestroy() {
        breathing?.cancel()
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    @Deprecated("Used below Android 13 only; newer versions use onBackInvokedDispatcher.")
    override fun onBackPressed() = goHome()

    private fun text(value: String, size: Float, color: Int, topDp: Int) = TextView(this).apply {
        text = value
        textSize = size
        setTextColor(color)
        gravity = Gravity.CENTER
        setPadding(0, (topDp * resources.displayMetrics.density).toInt(), 0, 0)
    }

    private fun openAnyway(pkg: String) {
        BlockingStore.allow(this, pkg, System.currentTimeMillis() + ALLOW_MINUTES * 60_000)
        packageManager.getLaunchIntentForPackage(pkg)?.let {
            startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
        finish()
    }

    // Back must never return to the blocked app, so it always goes to the home screen.
    private fun goHome() {
        startActivity(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        finish()
    }
}
