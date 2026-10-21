package com.acessor.motorista

import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

class FloatingDecisionService : Service() {
    private lateinit var windowManager: WindowManager
    private var card: LinearLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private var lastX = 0
    private var lastY = 0
    private var touchX = 0f
    private var touchY = 0f

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.getBooleanExtra(EXTRA_HIDE, false) == true) {
            removeCard()
            stopSelf()
            return START_NOT_STICKY
        }
        val label = intent?.getStringExtra(EXTRA_LABEL) ?: "ANALISANDO"
        val accepted = intent?.getBooleanExtra(EXTRA_ACCEPTED, false) ?: false
        val valueGood = intent?.getBooleanExtra(EXTRA_VALUE_GOOD, true) ?: true
        val perKmGood = intent?.getBooleanExtra(EXTRA_PER_KM_GOOD, true) ?: true
        val perHourGood = intent?.getBooleanExtra(EXTRA_PER_HOUR_GOOD, true) ?: true
        val distanceGood = intent?.getBooleanExtra(EXTRA_DISTANCE_GOOD, true) ?: true
        val timeGood = intent?.getBooleanExtra(EXTRA_TIME_GOOD, true) ?: true
        val value = intent?.getStringExtra(EXTRA_VALUE).orEmpty()
        val perKm = intent?.getStringExtra(EXTRA_PER_KM).orEmpty()
        val perHour = intent?.getStringExtra(EXTRA_PER_HOUR).orEmpty()
        val perMinute = intent?.getStringExtra(EXTRA_PER_MINUTE).orEmpty()
        val distance = intent?.getStringExtra(EXTRA_DISTANCE).orEmpty()
        val time = intent?.getStringExtra(EXTRA_TIME).orEmpty()
        val category = intent?.getStringExtra(EXTRA_CATEGORY).orEmpty()
        val rating = intent?.getStringExtra(EXTRA_RATING).orEmpty()
        val origin = intent?.getStringExtra(EXTRA_ORIGIN).orEmpty()
        val destination = intent?.getStringExtra(EXTRA_DESTINATION).orEmpty()
        showCard(label, accepted, value, perKm, perHour, perMinute, distance, time, category, rating, origin, destination, valueGood, perKmGood, perHourGood, distanceGood, timeGood)
        return START_NOT_STICKY
    }

    private fun showCard(
        label: String, accepted: Boolean, value: String, perKm: String, perHour: String,
        perMinute: String, distance: String, time: String, category: String, rating: String,
        origin: String, destination: String, valueGood: Boolean, perKmGood: Boolean,
        perHourGood: Boolean, distanceGood: Boolean, timeGood: Boolean
    ) {
        removeCard()
        val bg = GradientDrawable().apply {
            setColor(Color.argb(238, 28, 30, 36))
            cornerRadius = dp(14).toFloat()
            setStroke(dp(2), if (accepted) Color.rgb(54, 211, 125) else Color.rgb(248, 91, 91))
        }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(8), dp(12), dp(8))
            background = bg
            alpha = 0.96f
        }
        val headline = TextView(this).apply {
            text = if (accepted) "● $label" else "● $label"
            setTextColor(if (accepted) Color.rgb(72, 230, 142) else Color.rgb(255, 104, 104))
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
        }
        root.addView(headline)
        fun metricsRow(vararg items: Triple<String, String, Boolean>): LinearLayout {
            return LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                weightSum = items.size.toFloat()
                items.forEach { (title, amount, good) ->
                    val column = LinearLayout(this@FloatingDecisionService).apply {
                        orientation = LinearLayout.VERTICAL
                        setPadding(dp(5), dp(2), dp(5), dp(2))
                    }
                    column.addView(TextView(this@FloatingDecisionService).apply {
                        text = title
                        textSize = 9f
                        setTextColor(Color.LTGRAY)
                        maxLines = 1
                    })
                    column.addView(TextView(this@FloatingDecisionService).apply {
                        text = amount.ifBlank { "—" }
                        textSize = 15f
                        typeface = Typeface.DEFAULT_BOLD
                        setTextColor(if (good) Color.rgb(72, 230, 142) else Color.rgb(255, 104, 104))
                        maxLines = 1
                    })
                    addView(column, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
                }
            }
        }

        // Top row: per-kilometer and per-minute economics. Bottom row: total trip time and distance.
        val economics = metricsRow(
            Triple("R$/KM", perKm, perKmGood),
            Triple("R$/MIN", perMinute, perHourGood)
        )
        root.addView(economics)
        val totals = metricsRow(
            Triple("TEMPO TOTAL", time, timeGood),
            Triple("KM TOTAL", distance, distanceGood)
        )
        root.addView(totals)

        val details = listOfNotNull(
            category.takeIf { it.isNotBlank() },
            rating.takeIf { it.isNotBlank() },
            origin.takeIf { it.isNotBlank() },
            destination.takeIf { it.isNotBlank() }
        ).joinToString(" • ")
        if (details.isNotBlank()) root.addView(TextView(this).apply {
            text = details; textSize = 10f; setTextColor(Color.rgb(220, 223, 230))
            maxLines = 2
        })

        val p = params ?: WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            x = 0
            y = dp(100)
        }
        params = p
        root.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    lastX = p.x; lastY = p.y; touchX = event.rawX; touchY = event.rawY; true
                }
                MotionEvent.ACTION_MOVE -> {
                    p.x = lastX + (event.rawX - touchX).toInt()
                    p.y = (lastY + (event.rawY - touchY).toInt()).coerceAtLeast(dp(24))
                    runCatching { windowManager.updateViewLayout(root, p) }
                    true
                }
                else -> false
            }
        }
        card = root
        runCatching { windowManager.addView(root, p) }.onFailure { card = null }
    }

    private fun removeCard() {
        card?.let { runCatching { windowManager.removeView(it) } }
        card = null
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    override fun onDestroy() { removeCard(); super.onDestroy() }
    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val EXTRA_HIDE = "hide"
        const val EXTRA_LABEL = "label"
        const val EXTRA_ACCEPTED = "accepted"
        const val EXTRA_VALUE_GOOD = "value_good"
        const val EXTRA_PER_KM_GOOD = "per_km_good"
        const val EXTRA_PER_HOUR_GOOD = "per_hour_good"
        const val EXTRA_DISTANCE_GOOD = "distance_good"
        const val EXTRA_TIME_GOOD = "time_good"
        const val EXTRA_VALUE = "value"
        const val EXTRA_PER_KM = "per_km"
        const val EXTRA_PER_HOUR = "per_hour"
        const val EXTRA_PER_MINUTE = "per_minute"
        const val EXTRA_DISTANCE = "distance"
        const val EXTRA_TIME = "time"
        const val EXTRA_CATEGORY = "category"
        const val EXTRA_RATING = "rating"
        const val EXTRA_ORIGIN = "origin"
        const val EXTRA_DESTINATION = "destination"
    }
}
