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

        // Prefer the node that triggered the event: the active window may be stale
        // or may not represent the UI element that actually changed.
        val sourceText = runCatching { event.source?.let { buildText(it) } }.getOrNull().orEmpty().trim()
        val rootText = if (sourceText.isBlank()) {
            runCatching { rootInActiveWindow?.let { buildText(it) } }.getOrNull().orEmpty().trim()
        } else {
            ""
        }
        val text = if (sourceText.isNotBlank()) sourceText else rootText
        val captureSource = if (sourceText.isNotBlank()) "event_source" else "active_window"

        // Send even empty captures for diagnostics, so the app can distinguish
        // "no event" from "event arrived but no accessible text was exposed".
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
