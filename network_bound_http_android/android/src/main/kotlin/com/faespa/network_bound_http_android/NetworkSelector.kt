package com.faespa.network_bound_http_android

import android.content.Context
import android.net.*
import android.util.Log
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout
import kotlin.coroutines.resume
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resumeWithException


class NetworkSelector(private val context: Context) {

    suspend fun acquireInternal(network: CustomNetwork): Network?{
        return suspendCancellableCoroutine { cont ->
            Log.d("CUSTOM-LOGS", "NetworkSelector: entered in acquireInternal function")
            if (network == CustomNetwork.ANY) {
                // if we can use any network, we don't have to acquire it
                cont.resumeWithException(IllegalArgumentException("ANY network cannot be acquired"))
                return@suspendCancellableCoroutine
            }
            Log.d("CUSTOM-LOGS", "NetworkSelector: setting connectionManager");

            val connManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

            Log.d("CUSTOM-LOGS", "NetworkSelector: setting request");
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

            Log.d("CUSTOM-LOGS", "NetworkSelector: setting callback");
            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    Log.d("CUSTOM-LOGS", "NetworkSelector: network is available");
                    connManager.unregisterNetworkCallback(this)
                    cont.resume(network)
                }

                override fun onUnavailable() {
                    Log.d("CUSTOM-LOGS", "NetworkSelector: network is not available");
                    cont.resumeWithException(RuntimeException("Network ${network.name} unavailable"))
                }
            }

            Log.d("CUSTOM-LOGS", "NetworkSelector: requesting network");
            connManager.requestNetwork(request, callback)
            Log.d("CUSTOM-LOGS", "NetworkSelector: network requested");
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
