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

        // Never parse text from another app's window (for example, our own
        // diagnostic screen or an accessibility overlay). Node package names
        // are checked independently because active-window roots can be stale.
        val source = runCatching { event.source }.getOrNull()
        val sourcePackage = runCatching { source?.packageName?.toString() }.getOrNull()
        // Some Android/MIUI accessibility events omit the source node's package
        // even though the event itself came from the target app. In that case,
        // inspect only event.source (not the active window) as a safe first fallback.
        val sourceText = if (sourcePackage == packageName || (source != null && sourcePackage.isNullOrBlank())) {
            runCatching { source?.let { buildText(it) } }.getOrNull().orEmpty().trim()
        } else {
            ""
        }

        val root = if (sourceText.isBlank()) {
            runCatching { rootInActiveWindow }.getOrNull()
        } else {
            null
        }
        val rootPackage = runCatching { root?.packageName?.toString() }.getOrNull()
        val rootText = if (sourceText.isBlank() && rootPackage == packageName) {
            runCatching { root?.let { buildText(it) } }.getOrNull().orEmpty().trim()
        } else {
            ""
        }

        // Some driver apps render offers in a separate interactive window.
        // Search only windows owned by the event package; never read our own overlay.
        var matchingWindowText = ""
        if (sourceText.isBlank() && rootText.isBlank()) {
            matchingWindowText = runCatching {
                windows.asSequence()
                    .mapNotNull { window -> runCatching { window.root }.getOrNull() }
                    .filter { windowRoot ->
                        runCatching { windowRoot.packageName?.toString() == packageName }.getOrDefault(false)
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
            rootText.isNotBlank() -> rootText
            else -> matchingWindowText
        }
        val captureSource = when {
            sourceText.isNotBlank() -> "event_source"
            rootText.isNotBlank() -> "active_window"
            matchingWindowText.isNotBlank() -> "matching_window"
            else -> "no_matching_app_node"
        }

        // Keep empty events for diagnostics, but never substitute text from
        // another package just to make the capture appear populated.
        sendBroadcast(Intent(ACTION_OFFER_TEXT).apply {
            setPackage(applicationContext.packageName)
            putExtra(EXTRA_PACKAGE, packageName)
            putExtra(EXTRA_TEXT, text)
            putExtra(EXTRA_EVENT_TYPE, event.eventType)
            putExtra(EXTRA_CAPTURE_SOURCE, captureSource)
        })
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
    }
}
