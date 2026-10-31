package com.zyang.gainpath

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

/** OS availability hints only; never claims that Firebase is reachable. */
class NetworkOpportunitiesPlugin : FlutterPlugin, EventChannel.StreamHandler {
    private var channel: EventChannel? = null
    private var manager: ConnectivityManager? = null
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        manager = binding.applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        channel = EventChannel(binding.binaryMessenger, "gainpath/network_opportunities").also {
            it.setStreamHandler(this)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        onCancel(null)
        sink = events
        val listener = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                main.post { if (sink === events) events.success(true) }
            }
        }
        callback = listener
        try {
            manager?.registerNetworkCallback(NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET).build(), listener)
        } catch (_: RuntimeException) {
            callback = null
            events.error("unavailable", "Network availability hints unavailable", null)
        }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        callback?.let { listener ->
            try { manager?.unregisterNetworkCallback(listener) } catch (_: RuntimeException) { }
        }
        callback = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        onCancel(null)
        channel?.setStreamHandler(null)
        channel = null
        manager = null
    }
}
