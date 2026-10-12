package com.ipchanger.ip_changer

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Android gives ordinary apps no API to switch mobile data, so this service opens a
 * system screen that has the mobile data switch and clicks it: off, wait, on.
 * TelephonyManager is the source of truth for whether each click worked.
 */
class DataToggleService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: DataToggleService? = null
            private set

        private const val TICK_MS = 500L
        private const val CLICK_COOLDOWN_MS = 2500L
        private const val PHASE_TIMEOUT_MS = 20_000L
        private const val MAX_NODES = 3000

        private val DEFAULT_LABELS = listOf("mobile data", "cellular data")
        private val ID_HINTS = listOf("mobile_toggle", "mobile_data")
        private val CONFIRM_LABELS = listOf("turn off", "ok")

        fun isMobileDataEnabled(context: Context): Boolean {
            return try {
                val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                val subId = SubscriptionManager.getDefaultDataSubscriptionId()
                val forSub = if (subId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
                    tm.createForSubscriptionId(subId)
                } else {
                    tm
                }
                forSub.isDataEnabled
            } catch (e: SecurityException) {
                true
            }
        }
    }

    private enum class Phase { IDLE, TURNING_OFF, WAITING, TURNING_ON }

    private val handler = Handler(Looper.getMainLooper())
    private var phase = Phase.IDLE
    private var phaseStart = 0L
    private var lastClick = 0L
    private var clickedInPhase = false
    private var waitMs = 5000L
    private var labels = DEFAULT_LABELS
    private var callback: ((String?) -> Unit)? = null

    private val tick = object : Runnable {
        override fun run() {
            step()
            if (phase == Phase.TURNING_OFF || phase == Phase.TURNING_ON) {
                handler.postDelayed(this, TICK_MS)
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        if (phase != Phase.IDLE) finish("service_stopped")
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    /** Runs one off/wait/on cycle. [onDone] receives null on success or an error code. */
    fun start(waitSeconds: Int, screen: String, customLabel: String?, onDone: (String?) -> Unit) {
        if (phase != Phase.IDLE) {
            onDone("busy")
            return
        }
        waitMs = waitSeconds.coerceIn(1, 120) * 1000L
        val custom = customLabel?.trim()?.lowercase().orEmpty()
        labels = if (custom.isEmpty()) DEFAULT_LABELS else listOf(custom) + DEFAULT_LABELS
        callback = onDone

        val action = when (screen) {
            "data_usage" -> Settings.ACTION_DATA_USAGE_SETTINGS
            "mobile_network" -> Settings.ACTION_DATA_ROAMING_SETTINGS
            else -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                Settings.Panel.ACTION_INTERNET_CONNECTIVITY
            } else {
                Settings.ACTION_DATA_USAGE_SETTINGS
            }
        }
        try {
            startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: Exception) {
            callback = null
            onDone("screen_unavailable")
            return
        }
        enterPhase(Phase.TURNING_OFF)
        handler.postDelayed(tick, 800)
    }

    private fun enterPhase(next: Phase) {
        phase = next
        phaseStart = SystemClock.elapsedRealtime()
        lastClick = 0L
        clickedInPhase = false
    }

    private fun step() {
        val enabled = isMobileDataEnabled(this)
        when (phase) {
            Phase.TURNING_OFF -> if (!enabled) {
                phase = Phase.WAITING
                handler.postDelayed({
                    enterPhase(Phase.TURNING_ON)
                    handler.post(tick)
                }, waitMs)
            } else {
                attempt()
            }
            Phase.TURNING_ON -> if (enabled) finish(null) else attempt()
            else -> {}
        }
    }

    private fun attempt() {
        val now = SystemClock.elapsedRealtime()
        if (now - phaseStart > PHASE_TIMEOUT_MS) {
            val reason = if (clickedInPhase) "toggle_no_effect" else "toggle_not_found"
            finish(if (phase == Phase.TURNING_ON) "${reason}_data_off" else reason)
            return
        }
        val roots = collectRoots()
        if (now - lastClick < CLICK_COOLDOWN_MS) {
            // Some phones ask "Turn off mobile data?" before switching off.
            if (phase == Phase.TURNING_OFF) {
                roots.firstNotNullOfOrNull { findConfirmButton(it) }
                    ?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
            return
        }
        val toggle = roots.firstNotNullOfOrNull { findToggle(it, exact = true) }
            ?: roots.firstNotNullOfOrNull { findToggle(it, exact = false) }
            ?: return
        if (click(toggle)) {
            lastClick = now
            clickedInPhase = true
        }
    }

    private fun finish(error: String?) {
        val turnedBackOn = phase == Phase.TURNING_ON && error == null
        phase = Phase.IDLE
        handler.removeCallbacksAndMessages(null)
        // On failure the settings screen stays open so the switch can be fixed by hand.
        if (turnedBackOn) {
            performGlobalAction(GLOBAL_ACTION_BACK)
            handler.postDelayed({ bringAppToFront() }, 400)
        }
        val cb = callback
        callback = null
        cb?.invoke(error)
    }

    private fun bringAppToFront() {
        try {
            packageManager.getLaunchIntentForPackage(packageName)?.let {
                startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
        } catch (e: Exception) {
        }
    }

    private fun collectRoots(): List<AccessibilityNodeInfo> {
        val roots = try {
            windows.mapNotNull { it.root }
        } catch (e: Exception) {
            emptyList()
        }
        return roots.ifEmpty { listOfNotNull(rootInActiveWindow) }
    }

    private inline fun walk(root: AccessibilityNodeInfo, visit: (AccessibilityNodeInfo) -> Boolean) {
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < MAX_NODES) {
            val node = queue.removeFirst()
            visited++
            if (visit(node)) return
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { queue.add(it) }
            }
        }
    }

    private fun findToggle(root: AccessibilityNodeInfo, exact: Boolean): AccessibilityNodeInfo? {
        var found: AccessibilityNodeInfo? = null
        walk(root) { node ->
            if (matchesLabel(node, exact)) found = resolveSwitch(node)
            found != null
        }
        return found
    }

    private fun matchesLabel(node: AccessibilityNodeInfo, exact: Boolean): Boolean {
        val id = node.viewIdResourceName?.lowercase()
        if (id != null && ID_HINTS.any { id.contains(it) }) return true
        val texts = listOfNotNull(node.text, node.contentDescription)
            .map { it.toString().trim().lowercase() }
        return texts.any { text ->
            labels.any { label -> if (exact) text == label else text.contains(label) }
        }
    }

    /** The switch belonging to a label: the node itself, or the only switch in its row. */
    private fun resolveSwitch(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isCheckable) return node
        var current = node.parent
        repeat(3) {
            val container = current ?: return null
            val switches = mutableListOf<AccessibilityNodeInfo>()
            walk(container) { child ->
                if (child.isCheckable) switches.add(child)
                switches.size > 1
            }
            if (switches.size == 1) return switches[0]
            if (switches.size > 1) return null
            current = container.parent
        }
        return null
    }

    private fun findConfirmButton(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        var found: AccessibilityNodeInfo? = null
        walk(root) { node ->
            val text = node.text?.toString()?.trim()?.lowercase()
            if (node.isClickable && text != null && text in CONFIRM_LABELS) found = node
            found != null
        }
        return found
    }

    private fun click(node: AccessibilityNodeInfo): Boolean {
        var target: AccessibilityNodeInfo? = node
        repeat(4) {
            val current = target ?: return false
            if (current.isClickable) {
                return current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
            target = current.parent
        }
        return false
    }
}
