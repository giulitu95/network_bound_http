package com.faespa.network_bound_http_android

import android.content.Context
import android.net.*
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlinx.coroutines.withTimeout


class NetworkSelector(private val context: Context) {

    suspend fun acquire(
        type: NetworkType,
        timeoutMs: Int
    ): Network? = withTimeout(timeoutMs.toLong()) {
        suspendCancellableCoroutine { cont ->

            if (type == NetworkType.ANY) {
                cont.resume(null)
                return@suspendCancellableCoroutine
            }

            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .addTransportType(
                    when (type) {
                        NetworkType.WIFI -> NetworkCapabilities.TRANSPORT_WIFI
                        NetworkType.CELLULAR -> NetworkCapabilities.TRANSPORT_CELLULAR
                        else -> NetworkCapabilities.TRANSPORT_WIFI
                    }
                )
                .build()

            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    cm.unregisterNetworkCallback(this)
                    cont.resume(network)
                }

                override fun onUnavailable() {
                    cont.resume(null)
                }
            }

            cm.requestNetwork(request, callback)
        }
    }
}

enum class NetworkType {
    ANY, WIFI, CELLULAR
}
