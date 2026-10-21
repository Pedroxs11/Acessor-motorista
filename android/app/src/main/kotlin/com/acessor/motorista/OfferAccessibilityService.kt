package com.acessor.motorista

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class OfferAccessibilityService : AccessibilityService() {
    private var backgroundFlutterEngine: FlutterEngine? = null
    private var backgroundChannel: MethodChannel? = null
    private var backgroundReady = false
    private val pendingOffers = ArrayDeque<Pair<String, String>>()
    private var lastBackgroundFingerprint: String = ""

    override fun onServiceConnected() {
        super.onServiceConnected()
        runCatching {
            val engine = FlutterEngine(applicationContext)
            backgroundFlutterEngine = engine
            val channel = MethodChannel(
                engine.dartExecutor.binaryMessenger,
                "com.acessor.motorista/background_offer_processor"
            )
            backgroundChannel = channel
            channel.setMethodCallHandler { call, result ->
                if (call.method == "processorReady") {
                    backgroundReady = true
                    result.success(true)
                    while (pendingOffers.isNotEmpty()) {
                        val (packageName, text) = pendingOffers.removeFirst()
                        processOfferInBackground(packageName, text)
                    }
                } else {
                    result.notImplemented()
                }
            }
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                    "backgroundOfferMain"
                )
            )
        }.onFailure {
            backgroundReady = false
        }
    }

    private fun processOfferInBackground(packageName: String, text: String) {
        if (text.isBlank()) return
        if (!backgroundReady) {
            if (pendingOffers.size >= 10) pendingOffers.removeFirst()
            pendingOffers.addLast(packageName to text)
            return
        }
        val fingerprint = "$packageName|$text"
        if (fingerprint == lastBackgroundFingerprint) return
        val prefs = getSharedPreferences("driver_criteria", MODE_PRIVATE)
        val criteria = mapOf(
            "minValue" to prefs.getFloat("minValue", 0f).toDouble(),
            "minReaisPerKm" to prefs.getFloat("minReaisPerKm", 2f).toDouble(),
            "minReaisPerHour" to prefs.getFloat("minReaisPerHour", 40f).toDouble(),
            "maxPickupDistanceKm" to prefs.getFloat("maxPickupDistanceKm", 0f).toDouble(),
            "maxPickupTimeMin" to prefs.getInt("maxPickupTimeMin", 0)
        )
        backgroundChannel?.invokeMethod(
            "processOffer",
            mapOf(
                "packageName" to packageName,
                "text" to text,
                "criteriaEnabled" to prefs.getBoolean("enabled", false),
                "criteria" to criteria
            ),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    val data = result as? Map<*, *> ?: return
                    lastBackgroundFingerprint = fingerprint
                    val intent = Intent(this@OfferAccessibilityService, FloatingDecisionService::class.java)
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
                    intent.putExtra(FloatingDecisionService.EXTRA_ORIGIN, data["origin"]?.toString().orEmpty())
                    intent.putExtra(FloatingDecisionService.EXTRA_DESTINATION, data["destination"]?.toString().orEmpty())
                    startService(intent)
                }
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit
                override fun notImplemented() = Unit
            }
        )
    }

    override fun onDestroy() {
        backgroundFlutterEngine?.destroy()
        backgroundFlutterEngine = null
        backgroundChannel = null
        backgroundReady = false
        pendingOffers.clear()
        super.onDestroy()
    }
    private val targetPackages = setOf(
        "com.ubercab.driver",
        "com.app99.driver",
        "br.com.ifood.driver.app",
        "com.rappi.storekeeper",
        "com.lalamove.global.driver.sea",
        "com.loggi.driverapp",
        "global.dostavista.courier"
    )

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString() ?: return
        if (packageName !in targetPackages) return

        // Read the cheap event payload first. On busy offer screens, traversing
        // the source tree before checking event.text can delay the useful offer.
        val eventText = runCatching {
            event.text.joinToString(" ") { item -> item?.toString().orEmpty().trim() }
                .ifBlank { event.contentDescription?.toString().orEmpty().trim() }
        }.getOrDefault("")

        val source = if (eventText.isBlank()) runCatching { event.source }.getOrNull() else null
        val sourcePackage = runCatching { source?.packageName?.toString() }.getOrNull()
        val sourceText = if (eventText.isBlank() &&
            (sourcePackage == packageName || (source != null && sourcePackage.isNullOrBlank()))
        ) {
            runCatching { source?.let { buildText(it) } }.getOrNull().orEmpty().trim()
        } else {
            ""
        }

        val root = if (eventText.isBlank() && sourceText.isBlank()) {
            runCatching { rootInActiveWindow }.getOrNull()
        } else {
            null
        }
        val rootPackage = runCatching { root?.packageName?.toString() }.getOrNull()
        val rootText = if (eventText.isBlank() && sourceText.isBlank() &&
            rootPackage == packageName
        ) {
            runCatching { root?.let { buildText(it) } }.getOrNull().orEmpty().trim()
        } else {
            ""
        }

        var matchingWindowText = ""
        if (eventText.isBlank() && sourceText.isBlank() && rootText.isBlank()) {
            matchingWindowText = runCatching {
                windows.asSequence()
                    .mapNotNull { window -> runCatching { window.root }.getOrNull() }
                    .filter { windowRoot ->
                        runCatching { windowRoot.packageName?.toString() == packageName }
                            .getOrDefault(false)
                    }
                    .mapNotNull { windowRoot ->
                        runCatching { buildText(windowRoot).trim() }.getOrNull()
                    }
                    .firstOrNull { it.isNotBlank() }
                    .orEmpty()
            }.getOrDefault("")
        }

        val text = when {
            eventText.isNotBlank() -> eventText
            sourceText.isNotBlank() -> sourceText
            rootText.isNotBlank() -> rootText
            else -> matchingWindowText
        }
        val captureSource = when {
            eventText.isNotBlank() -> "event_text"
            sourceText.isNotBlank() -> "event_source"
            rootText.isNotBlank() -> "active_window"
            matchingWindowText.isNotBlank() -> "matching_window"
            else -> "no_matching_app_node"
        }

        val debugDetails = if (text.isBlank()) {
            val sourceNodeCount = runCatching {
                source?.let { countTextNodes(it) } ?: 0
            }.getOrDefault(-1)
            val rootNodeCount = runCatching {
                root?.let { countTextNodes(it) } ?: 0
            }.getOrDefault(-1)
            val windowDiagnostics = runCatching {
                windows.mapNotNull { window ->
                    val windowRoot = runCatching { window.root }.getOrNull()
                        ?: return@mapNotNull null
                    val owner = runCatching {
                        windowRoot.packageName?.toString()
                    }.getOrNull() ?: "null"
                    val nodeCount = countTextNodes(windowRoot)
                    "$owner:nodes=$nodeCount"
                }.take(8).joinToString(",")
            }.getOrDefault("windows_unavailable")
            "event=${event.eventType};sourcePkg=${sourcePackage ?: "null"};sourceNodes=$sourceNodeCount;eventTextChars=${eventText.length};activePkg=${rootPackage ?: "null"};activeNodes=$rootNodeCount;windows=[$windowDiagnostics]"
        } else {
            "event=${event.eventType};capture=$captureSource;chars=${text.length}"
        }

        processOfferInBackground(packageName, text)

        sendBroadcast(Intent(ACTION_OFFER_TEXT).apply {
            setPackage(applicationContext.packageName)
            putExtra(EXTRA_PACKAGE, packageName)
            putExtra(EXTRA_TEXT, text)
            putExtra(EXTRA_EVENT_TYPE, event.eventType)
            putExtra(EXTRA_CAPTURE_SOURCE, captureSource)
            putExtra(EXTRA_DEBUG_DETAILS, debugDetails)
        })
    }

    private fun countTextNodes(node: AccessibilityNodeInfo): Int {
        var count = 0
        fun visit(current: AccessibilityNodeInfo?) {
            if (current == null) return
            if (!current.text.isNullOrBlank() || !current.contentDescription.isNullOrBlank()) count++
            for (i in 0 until current.childCount) {
                runCatching { current.getChild(i) }.getOrNull()?.let(::visit)
            }
        }
        visit(node)
        return count
    }

    private fun buildText(node: AccessibilityNodeInfo): String {
        val result = StringBuilder()
        val visited = HashSet<String>()
        fun visit(current: AccessibilityNodeInfo?) {
            if (current == null) return
            current.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let {
                if (visited.add("t:$it")) result.append(it).append(' ')
            }
            current.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let {
                if (visited.add("d:$it")) result.append(it).append(' ')
            }
            for (i in 0 until current.childCount) {
                runCatching { current.getChild(i) }.getOrNull()?.let(::visit)
            }
        }
        visit(node)
        return result.toString()
    }

    override fun onInterrupt() = Unit

    companion object {
        const val ACTION_OFFER_TEXT = "com.acessor.motorista.ACTION_OFFER_TEXT"
        const val EXTRA_PACKAGE = "package_name"
        const val EXTRA_TEXT = "offer_text"
        const val EXTRA_EVENT_TYPE = "event_type"
        const val EXTRA_CAPTURE_SOURCE = "capture_source"
        const val EXTRA_DEBUG_DETAILS = "debug_details"
    }
}
