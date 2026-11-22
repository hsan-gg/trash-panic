package com.lastdrop.netinfo

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import android.telephony.TelephonyCallback
import android.telephony.TelephonyDisplayInfo
import android.telephony.TelephonyManager
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * Reports which network the phone is using right now (WIFI, 5G_SA, 5G_NSA, 4G, 3G, ...).
 * The game works on any of them; this only detects and reports. GDScript: Engine.get_singleton("NetInfo").
 */
class NetInfo(godot: Godot) : GodotPlugin(godot) {

    private val cm by lazy { activity!!.getSystemService(ConnectivityManager::class.java) }
    private val tm by lazy { activity!!.getSystemService(TelephonyManager::class.java) }

    @Volatile private var displayOverride = TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_NONE
    @Volatile private var displayNetworkType = TelephonyManager.NETWORK_TYPE_UNKNOWN
    @Volatile private var lastReported = ""
    private var started = false
    private var displayListenerRegistered = false

    override fun getPluginName() = "NetInfo"

    override fun getPluginSignals() = setOf(SignalInfo("net_changed", String::class.java))

    private val defaultCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = notifyChanged()
        override fun onLost(network: Network) = notifyChanged()
        override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) = notifyChanged()
    }

    @UsedByGodot
    fun start() {
        if (started) return
        started = true
        cm.registerDefaultNetworkCallback(defaultCallback)
        listenDisplayInfo()
        notifyChanged()
    }

    /**
     * The radio type (5G SA, 5G NSA, 4G...) comes from the display info, which Android 12+ hands out without any
     * permission, so the game never asks for phone access. Where it is refused, mobile data shows as plain CELL.
     */
    private fun listenDisplayInfo() {
        if (displayListenerRegistered || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        try {
            tm.registerTelephonyCallback(activity!!.mainExecutor, DisplayInfoListener())
            displayListenerRegistered = true
        } catch (e: SecurityException) {
            displayListenerRegistered = false
        }
    }

    @UsedByGodot
    fun getNetType(): String {
        val network = cm.activeNetwork ?: return "NONE"
        val caps = cm.getNetworkCapabilities(network) ?: return "NONE"
        return when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> cellularType()
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "WIFI"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ETHERNET"
            else -> "OTHER"
        }
    }

    /** Identifies the network carrying traffic. A socket stays on the network it was opened on, so the game reopens it when this changes. */
    @UsedByGodot
    fun getNetworkHandle(): Long = cm.activeNetwork?.networkHandle ?: 0L

    private fun cellularType(): String {
        if (!displayListenerRegistered) return "CELL"  // no display info: we know it's mobile data, not which kind
        return when (displayNetworkType) {
            TelephonyManager.NETWORK_TYPE_NR -> "5G_SA"
            TelephonyManager.NETWORK_TYPE_LTE -> when (displayOverride) {
                TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_NR_NSA,
                TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_NR_ADVANCED -> "5G_NSA"
                else -> "4G"
            }
            TelephonyManager.NETWORK_TYPE_UNKNOWN -> "CELL"
            else -> "3G"
        }
    }

    /** Signal strength changes fire the callbacks constantly; only tell the game when something it shows changed. */
    private fun notifyChanged() {
        val type = getNetType()
        val key = type + "|" + getNetworkHandle()
        if (key == lastReported) return
        lastReported = key
        runOnRenderThread { emitSignal("net_changed", type) }
    }

    private inner class DisplayInfoListener : TelephonyCallback(), TelephonyCallback.DisplayInfoListener {
        override fun onDisplayInfoChanged(info: TelephonyDisplayInfo) {
            displayOverride = info.overrideNetworkType
            displayNetworkType = info.networkType
            notifyChanged()
        }
    }
}
