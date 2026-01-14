package com.faespa.network_bound_http_android

import android.content.Context
import android.net.*
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout
import kotlin.coroutines.resume
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resumeWithException


class NetworkSelector(private val context: Context) {

    suspend fun acquireInternal(network: CustomNetwork): Network?{
        return suspendCancellableCoroutine { cont ->

            if (network == CustomNetwork.ANY) {
                // if we can use any network, we don't have to acquire it
                cont.resumeWithException(IllegalArgumentException("ANY network cannot be acquired"))
                return@suspendCancellableCoroutine
            }

            val connManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .addTransportType(
                    when (network) {
                        CustomNetwork.WIFI -> NetworkCapabilities.TRANSPORT_WIFI
                        CustomNetwork.CELLULAR -> NetworkCapabilities.TRANSPORT_CELLULAR
                        else -> NetworkCapabilities.TRANSPORT_WIFI // it should never reach here
                    }
                )
                .build()

            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    connManager.unregisterNetworkCallback(this)
                    cont.resume(network)
                }

                override fun onUnavailable() {
                    cont.resumeWithException(RuntimeException("Network ${network.name} unavailable"))
                }
            }

            connManager.requestNetwork(request, callback)
        }
    }
    suspend fun acquire(
        network: CustomNetwork,
        timeout: Int?
    ): Network? =
        timeout?.let {
            withTimeout(it.toLong()) { acquireInternal(network) }
        } ?: acquireInternal(network)
}

enum class CustomNetwork {
    ANY, WIFI, CELLULAR
}
