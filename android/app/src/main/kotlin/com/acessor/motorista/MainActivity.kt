package com.acessor.motorista

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.acessor.motorista/offer_capture"
    private var eventSink: EventChannel.EventSink? = null

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != OfferAccessibilityService.ACTION_OFFER_TEXT) return

            val packageName = intent.getStringExtra(OfferAccessibilityService.EXTRA_PACKAGE) ?: return
            val text = intent.getStringExtra(OfferAccessibilityService.EXTRA_TEXT) ?: return

            eventSink?.success(mapOf(
                "packageName" to packageName,
                "text" to text,
            ))
        }
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        registerReceiver(
            receiver,
            IntentFilter(OfferAccessibilityService.ACTION_OFFER_TEXT),
            Context.RECEIVER_NOT_EXPORTED,
        )
    }

    override fun onDestroy() {
        unregisterReceiver(receiver)
        eventSink = null
        super.onDestroy()
    }
}
