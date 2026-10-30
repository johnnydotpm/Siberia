package app.syberia.client

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Tells Dart whether a VPN carries the phone's traffic now, so the app can
 * say that Librus sometimes blocks VPNs only while one is on.
 */
object VpnChannel {
    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "app.syberia.client/vpn").setMethodCallHandler { call, result ->
            if (call.method == "active") {
                result.success(active(app))
            } else {
                result.notImplemented()
            }
        }
    }

    /** True with a VPN on, false without, null when the system cannot say. */
    private fun active(context: Context): Boolean? {
        return try {
            val manager = context.getSystemService(ConnectivityManager::class.java)
                ?: return null
            val network = manager.activeNetwork ?: return false
            val capabilities = manager.getNetworkCapabilities(network) ?: return false
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
        } catch (error: RuntimeException) {
            // Without ACCESS_NETWORK_STATE, or on an unusual system.
            null
        }
    }
}
