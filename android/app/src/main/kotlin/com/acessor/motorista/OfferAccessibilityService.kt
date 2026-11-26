package com.acessor.motorista

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.Rect
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class OfferAccessibilityService : AccessibilityService() {
    private val targetPackages = setOf(
        "com.ubercab.driver",
        "com.app99.driver",
        "br.com.ifood.driver.app",
        "com.rappi.storekeeper",
        "com.lalamove.global.driver.sea",
        "com.loggi.driverapp",
        "global.dostavista.courier"
    )

    private val moneyPattern = Regex("""r[$]\s*\d""", RegexOption.IGNORE_CASE)
    private val distancePattern = Regex("""\d\s*(?:km|m)\b""", RegexOption.IGNORE_CASE)

    private var lastTreeScanAt = 0L

    private fun looksLikeOffer(text: String): Boolean =
        moneyPattern.containsMatchIn(text) && distancePattern.containsMatchIn(text)

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString() ?: return
        if (packageName !in targetPackages) return

        var bestText = ""
        var bestSource = "no_matching_app_node"

        fun consider(candidate: String?, label: String): Boolean {
            val trimmed = candidate.orEmpty().trim()
            if (trimmed.isEmpty()) return false
            if (looksLikeOffer(trimmed)) {
                bestText = trimmed
                bestSource = label
                return true
            }
            if (trimmed.length > bestText.length) {
                bestText = trimmed
                bestSource = label
            }
            return false
        }

        val eventText = runCatching {
            event.text.joinToString(" ") { item -> item?.toString().orEmpty().trim() }
                .ifBlank { event.contentDescription?.toString().orEmpty().trim() }
        }.getOrDefault("")
        var found = consider(eventText, "event_text")

        val now = SystemClock.elapsedRealtime()
        val scanTree = !found && now - lastTreeScanAt >= TREE_SCAN_INTERVAL_MS
        if (scanTree) lastTreeScanAt = now

        var sourcePackage: String? = null
        var rootPackage: String? = null

        if (scanTree) {
            val source = runCatching { event.source }.getOrNull()
            sourcePackage = runCatching { source?.packageName?.toString() }.getOrNull()
            if (source != null && (sourcePackage == packageName || sourcePackage.isNullOrBlank())) {
                found = consider(runCatching { buildText(source) }.getOrNull(), "event_source")
            }
        }

        if (scanTree && !found) {
            val root = runCatching { rootInActiveWindow }.getOrNull()
            rootPackage = runCatching { root?.packageName?.toString() }.getOrNull()
            if (root != null && rootPackage == packageName) {
                found = consider(runCatching { buildText(root) }.getOrNull(), "active_window")
            }
        }

        if (scanTree && !found) {
            val windowRoots = runCatching {
                windows.mapNotNull { window -> runCatching { window.root }.getOrNull() }
            }.getOrDefault(emptyList())
            for (windowRoot in windowRoots) {
                val owner = runCatching { windowRoot.packageName?.toString() }.getOrNull()
                if (owner != packageName) continue
                if (consider(runCatching { buildText(windowRoot) }.getOrNull(), "matching_window")) {
                    found = true
                    break
                }
            }
        }

        val captureSource = when {
            found -> bestSource
            bestText.isNotBlank() -> "partial:$bestSource"
            else -> "no_matching_app_node"
        }

        val debugDetails = when {
            found -> "event=${event.eventType};capture=$captureSource;chars=${bestText.length}"
            packageName == NINE_NINE_PACKAGE && scanTree ->
                "event=${event.eventType};best=$captureSource;bestChars=${bestText.length};" +
                    "sourcePkg=${sourcePackage ?: "null"};activePkg=${rootPackage ?: "null"};" +
                    "windows=[${windowDiagnostics()}]"
            else ->
                "event=${event.eventType};capture=$captureSource;chars=${bestText.length};scanned=$scanTree"
        }

        sendBroadcast(Intent(ACTION_OFFER_TEXT).apply {
            setPackage(applicationContext.packageName)
            putExtra(EXTRA_PACKAGE, packageName)
            putExtra(EXTRA_TEXT, bestText)
            putExtra(EXTRA_EVENT_TYPE, event.eventType)
            putExtra(EXTRA_CAPTURE_SOURCE, captureSource)
            putExtra(EXTRA_DEBUG_DETAILS, debugDetails)
        })
    }

    private fun windowDiagnostics(): String = runCatching {
        windows.mapNotNull { window ->
            val windowRoot = runCatching { window.root }.getOrNull() ?: return@mapNotNull null
            val owner = runCatching { windowRoot.packageName?.toString() }.getOrNull() ?: "null"
            "$owner:nodes=${countTextNodes(windowRoot)}"
        }.take(8).joinToString(",")
    }.getOrDefault("windows_unavailable")

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
        val bounds = Rect()
        fun visit(current: AccessibilityNodeInfo?) {
            if (current == null) return
            bounds.setEmpty()
            runCatching { current.getBoundsInScreen(bounds) }
            val where = bounds.flattenToString()
            current.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let {
                if (visited.add("$it@$where")) result.append(it).append(' ')
            }
            current.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let {
                if (visited.add("$it@$where")) result.append(it).append(' ')
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

        private const val NINE_NINE_PACKAGE = "com.app99.driver"
        private const val TREE_SCAN_INTERVAL_MS = 150L
    }
}