package com.acessor.motorista

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.acessor.motorista/offer_capture"
    private val overlayChannelName = "com.acessor.motorista/floating_overlay"
    private var eventSink: EventChannel.EventSink? = null

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != OfferAccessibilityService.ACTION_OFFER_TEXT) return
            val packageName = intent.getStringExtra(OfferAccessibilityService.EXTRA_PACKAGE) ?: return
            val text = intent.getStringExtra(OfferAccessibilityService.EXTRA_TEXT).orEmpty()
            val eventType = intent.getIntExtra(OfferAccessibilityService.EXTRA_EVENT_TYPE, -1)
            val captureSource = intent.getStringExtra(OfferAccessibilityService.EXTRA_CAPTURE_SOURCE) ?: "unknown"
            eventSink?.success(mapOf(
                "packageName" to packageName,
                "text" to text,
                "eventType" to eventType,
                "captureSource" to captureSource,
            ))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
                override fun onCancel(arguments: Any?) { eventSink = null }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, overlayChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this))
                    "hasAccessibilityPermission" -> result.success(isAccessibilityServiceEnabled())
                    "requestAccessibilityPermission" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "loadCriteria" -> {
                        val prefs = getSharedPreferences("driver_criteria", Context.MODE_PRIVATE)
                        result.success(mapOf(
                            "enabled" to prefs.getBoolean("enabled", false),
                            "minValue" to prefs.getFloat("minValue", 0f).toDouble(),
                            "minReaisPerKm" to prefs.getFloat("minReaisPerKm", 2f).toDouble(),
                            "minReaisPerHour" to prefs.getFloat("minReaisPerHour", 40f).toDouble(),
                            "maxPickupDistanceKm" to prefs.getFloat("maxPickupDistanceKm", 0f).toDouble(),
                            "maxPickupTimeMin" to prefs.getInt("maxPickupTimeMin", 0)
                        ))
                    }
                    "saveCriteria" -> {
                        val data = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        fun number(key: String, fallback: Float): Float {
                            val value = data[key]
                            return when (value) {
                                is Number -> value.toFloat()
                                else -> value?.toString()?.replace(',', '.')?.toFloatOrNull() ?: fallback
                            }
                        }
                        val prefs = getSharedPreferences("driver_criteria", Context.MODE_PRIVATE)
                        prefs.edit()
                            .putBoolean("enabled", true)
                            .putFloat("minValue", number("minValue", 0f))
                            .putFloat("minReaisPerKm", number("minReaisPerKm", 2f))
                            .putFloat("minReaisPerHour", number("minReaisPerHour", 40f))
                            .putFloat("maxPickupDistanceKm", number("maxPickupDistanceKm", 0f))
                            .putInt("maxPickupTimeMin", number("maxPickupTimeMin", 0f).toInt())
                            .apply()
                        result.success(true)
                    }
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                        }
                        result.success(null)
                    }
                    "show" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                            result.error("NO_OVERLAY_PERMISSION", "Permita a exibição sobre outros apps nas configurações do Android.", null)
                        } else {
                            val intent = Intent(this, FloatingDecisionService::class.java)
                            val data = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                            intent.putExtra(FloatingDecisionService.EXTRA_LABEL, data["label"]?.toString() ?: "ANALISANDO")
                            intent.putExtra(FloatingDecisionService.EXTRA_ACCEPTED, data["accepted"] as? Boolean ?: false)
                            intent.putExtra(FloatingDecisionService.EXTRA_VALUE_GOOD, data["valueGood"] as? Boolean ?: true)
                            intent.putExtra(FloatingDecisionService.EXTRA_PER_KM_GOOD, data["perKmGood"] as? Boolean ?: true)
                            intent.putExtra(FloatingDecisionService.EXTRA_PER_HOUR_GOOD, data["perHourGood"] as? Boolean ?: true)
                            intent.putExtra(FloatingDecisionService.EXTRA_DISTANCE_GOOD, data["distanceGood"] as? Boolean ?: true)
                            intent.putExtra(FloatingDecisionService.EXTRA_TIME_GOOD, data["timeGood"] as? Boolean ?: true)
                            intent.putExtra(FloatingDecisionService.EXTRA_VALUE, data["value"]?.toString().orEmpty())
                            intent.putExtra(FloatingDecisionService.EXTRA_PER_KM, data["perKm"]?.toString().orEmpty())
                            intent.putExtra(FloatingDecisionService.EXTRA_PER_HOUR, data["perHour"]?.toString().orEmpty())
                            intent.putExtra(FloatingDecisionService.EXTRA_PER_MINUTE, data["perMinute"]?.toString().orEmpty())
                            intent.putExtra(FloatingDecisionService.EXTRA_DISTANCE, data["distance"]?.toString().orEmpty())
                            intent.putExtra(FloatingDecisionService.EXTRA_TIME, data["time"]?.toString().orEmpty())
                            intent.putExtra(FloatingDecisionService.EXTRA_CATEGORY, data["category"]?.toString().orEmpty())
                            intent.putExtra(FloatingDecisionService.EXTRA_RATING, data["rating"]?.toString().orEmpty())
                            intent.putExtra(FloatingDecisionService.EXTRA_ORIGIN, data["origin"]?.toString().orEmpty())
                            intent.putExtra(FloatingDecisionService.EXTRA_DESTINATION, data["destination"]?.toString().orEmpty())
                            startService(intent)
                            result.success(null)
                        }
                    }
                    "hide" -> {
                        startService(Intent(this, FloatingDecisionService::class.java).putExtra(FloatingDecisionService.EXTRA_HIDE, true))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        registerReceiver(receiver, IntentFilter(OfferAccessibilityService.ACTION_OFFER_TEXT), Context.RECEIVER_NOT_EXPORTED)
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ).orEmpty()
        val target = ComponentName(this, OfferAccessibilityService::class.java).flattenToString()
        return enabledServices.split(':').any { it.equals(target, ignoreCase = true) }
    }

    override fun onDestroy() {
        runCatching { unregisterReceiver(receiver) }
        eventSink = null
        super.onDestroy()
    }
}
