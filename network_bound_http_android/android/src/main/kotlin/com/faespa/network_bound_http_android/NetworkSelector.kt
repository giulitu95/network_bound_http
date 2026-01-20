package com.faespa.network_bound_http_android

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException


enum class CustomNetwork {
    STANDARD, WIFI, CELLULAR
}

interface NetworkRequestFactory {
    fun create(network: CustomNetwork): NetworkRequest
}

interface NetworkSelector {
    suspend fun acquireNetwork(
        timeout: Long = 3500
    ): Network
}

class DefaultNetworkRequestFactory : NetworkRequestFactory {
    override fun create(network: CustomNetwork): NetworkRequest {
        val builder = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)

        when (network) {
            CustomNetwork.WIFI -> builder.addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            CustomNetwork.CELLULAR -> builder.addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
            else -> builder.addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
        }

        return builder.build()
    }
}

class DefaultNetworkSelector(
    private val context: Context,
    private val customNetwork: CustomNetwork,
    private val networkRequestFactory: NetworkRequestFactory = DefaultNetworkRequestFactory()
) : NetworkSelector {

    override suspend fun acquireNetwork(
        timeout: Long
    ): Network =
        withTimeout(timeout) {
            suspendCancellableCoroutine { cont ->

                try {
                    if (customNetwork != CustomNetwork.STANDARD) {
                        val connManager =
                            context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                        val netRequest = networkRequestFactory.create(customNetwork)
                        val callback = object : ConnectivityManager.NetworkCallback() {
                            override fun onAvailable(network: Network) {
                                if (cont.isActive) {
                                    cont.resume(network)
                                }
                            }

                            override fun onUnavailable() {
                                if (cont.isActive) {
                                    cont.resumeWithException(IllegalStateException("Network is not available"))
                                }
                            }
                        }
                        connManager.requestNetwork(netRequest, callback)
                        cont.invokeOnCancellation {
                            connManager.unregisterNetworkCallback(callback)
                        }
                    } else {
                        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE)
                                as ConnectivityManager

                        val network: Network? = cm.activeNetwork
                        if (network != null) {
                            cont.resume(network)
                        } else {
                            cont.resumeWithException(kotlin.IllegalStateException("No network found"))

                        }
                    }

                } catch (e: Exception) {
                    cont.resumeWithException(e)
                }
            }
        }

}