package com.acessor.motorista

import android.accessibilityservice.AccessibilityService
import android.content.Intent
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

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString() ?: return
        if (packageName !in targetPackages) return

        val source = runCatching { event.source }.getOrNull()
        val sourcePackage = runCatching { source?.packageName?.toString() }.getOrNull()
        val sourceText = if (sourcePackage == packageName ||
            (source != null && sourcePackage.isNullOrBlank())
        ) {
            runCatching { source?.let { buildText(it) } }.getOrNull().orEmpty().trim()
        } else {
            ""
        }

        val eventText = runCatching {
            event.text.joinToString(" ") { item -> item?.toString().orEmpty().trim() }
                .ifBlank { event.contentDescription?.toString().orEmpty().trim() }
        }.getOrDefault("")

        // Fast path: only query the active window when the event itself had no text.
        val root = if (sourceText.isBlank() && eventText.isBlank()) {
            runCatching { rootInActiveWindow }.getOrNull()
        } else {
            null
        }
        val rootPackage = runCatching { root?.packageName?.toString() }.getOrNull()
        val rootText = if (sourceText.isBlank() && eventText.isBlank() &&
            rootPackage == packageName
        ) {
            runCatching { root?.let { buildText(it) } }.getOrNull().orEmpty().trim()
        } else {
            ""
        }

        // Expensive multi-window traversal is a fallback, not part of every event.
        var matchingWindowText = ""
        if (sourceText.isBlank() && eventText.isBlank() && rootText.isBlank()) {
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
            sourceText.isNotBlank() -> sourceText
            eventText.isNotBlank() -> eventText
            rootText.isNotBlank() -> rootText
            else -> matchingWindowText
        }
        val captureSource = when {
            sourceText.isNotBlank() -> "event_source"
            eventText.isNotBlank() -> "event_text"
            rootText.isNotBlank() -> "active_window"
            matchingWindowText.isNotBlank() -> "matching_window"
            else -> "no_matching_app_node"
        }

        // Detailed node/window counts are only collected for failed captures.
        // This avoids recursively traversing the accessibility tree on every
        // event while keeping the diagnostics needed to troubleshoot the 99.
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
