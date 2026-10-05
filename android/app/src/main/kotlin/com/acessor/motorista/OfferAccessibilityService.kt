package com.acessor.motorista

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class OfferAccessibilityService : AccessibilityService() {
    private val targetPackages = setOf("com.ubercab.driver", "com.app99.driver", "br.com.ifood.driver.app")

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString() ?: return
        if (packageName !in targetPackages) return
        val root = rootInActiveWindow ?: return
        val text = buildText(root).trim()
        if (text.isBlank()) return

        val intent = Intent(ACTION_OFFER_TEXT).apply {
            setPackage(applicationContext.packageName)
            putExtra(EXTRA_PACKAGE, packageName)
            putExtra(EXTRA_TEXT, text)
        }
        sendBroadcast(intent)
        getSharedPreferences(PREFS, MODE_PRIVATE).edit()
            .putString(KEY_LAST_PACKAGE, packageName)
            .putString(KEY_LAST_TEXT, text)
            .apply()
    }

    private fun buildText(node: AccessibilityNodeInfo): String {
        val result = StringBuilder()
        fun visit(current: AccessibilityNodeInfo?) {
            if (current == null) return
            current.text?.toString()?.trim()?.let { if (it.isNotEmpty()) result.append(it).append(' ') }
            current.contentDescription?.toString()?.trim()?.let { if (it.isNotEmpty()) result.append(it).append(' ') }
            for (index in 0 until current.childCount) visit(current.getChild(index))
        }
        visit(node)
        return result.toString()
    }

    override fun onInterrupt() = Unit

    companion object {
        const val ACTION_OFFER_TEXT = "com.acessor.motorista.ACTION_OFFER_TEXT"
        const val EXTRA_PACKAGE = "package_name"
        const val EXTRA_TEXT = "offer_text"
        const val PREFS = "acessor_capture"
        const val KEY_LAST_PACKAGE = "last_package"
        const val KEY_LAST_TEXT = "last_text"
    }
}
