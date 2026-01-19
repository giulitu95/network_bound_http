package com.faespa.network_bound_http_android


import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException


enum class CustomNetwork {
    DEFAULT, WIFI, CELLULAR
}

class NativeHttpClient(
    private val context: Context,
    private val eventSink: EventChannel.EventSink,
) {
    private suspend fun emitToFlutter(
        payload: Map<String, Any?>
    ) = withContext(Dispatchers.Main) {
        eventSink.success(payload)
    }

    private suspend fun emitErrorToFlutter(
        errorCode: String,
        errorMessage: String?,
        errorDetails: String?
    ) = withContext(Dispatchers.Main) {
        eventSink.error(errorCode, errorMessage, errorDetails)
    }


    private suspend fun sendRequest(
        network: Network,
        request: HttpRequest,
    ) {
        Log.d("CUSTOM-LOGS", "sending request")
        val connection = network.openConnection(URL(request.uri)) as HttpURLConnection
        connection.requestMethod = request.method
        connection.connectTimeout = request.timeout
        connection.readTimeout = request.timeout
        request.headers.forEach { (k, v) ->
            connection.setRequestProperty(k, v)
        }
        if (request.body != null) {
            connection.doOutput = true
            connection.outputStream.use { it.write(request.body) }
        }
        connection.connect()
        val status = connection.responseCode

        val stream: InputStream? =
            if (status >= 400) connection.errorStream else connection.inputStream

        val file = File(request.outputPath)
        stream?.use { input ->
            FileOutputStream(file).use { output ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                var bytesRead: Int
                var downloaded: Long = 0
                val total = connection.contentLengthLong
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                    downloaded += bytesRead
                    emitToFlutter(
                        mapOf(
                            "id" to request.id,
                            "type" to "progress",
                            "downloaded" to downloaded,
                            "total" to total
                        )
                    )
                    Log.d("CUSTOM-LOGS", "NativeHttpClient: Progress sent")
                }
            }
        }
        Log.d("CUSTOM-LOGS", "NativeHttpClient: All progresses sent")
        val headersMap: Map<String, String> =
            connection.headerFields
                .filterKeys { it != null } // rimuove la status line
                .map { (key, values) ->
                    key!! to values.joinToString(", ")
                }
                .toMap()

        emitToFlutter(
            mapOf(
                "id" to request.id,
                "type" to "complete",
                "statusCode" to status,
                "headers" to headersMap,
                "outputFile" to request.outputPath
            )
        )
        Log.d("CUSTOM-LOGS", "Done!")
    }

    suspend fun acquireNetwork(
        network: CustomNetwork,
        timeout: Long = 3500
    ): Network =
        withTimeout(timeout) {
            suspendCancellableCoroutine { cont ->

                Log.d("CUSTOM-LOGS", "sending request 3")
                try {
                    if (network != CustomNetwork.DEFAULT) {
                        Log.d("CUSTOM-LOGS", "sending request 4")
                        val connManager =
                            context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                        val netRequest = NetworkRequest.Builder()
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
                                Log.d("CUSTOM-LOGS", "-----------> NET IS AVAILABLE")
                                if (cont.isActive) {
                                    cont.resume(network)
                                }
                            }

                            override fun onUnavailable() {

                                Log.d("CUSTOM-LOGS", "-----------> NET IS NOT AVAILABLE")
                                if (cont.isActive) {
                                    cont.resumeWithException(IllegalStateException("network is not availables"))
                                }
                            }
                        }
                        connManager.requestNetwork(netRequest, callback)
                        cont.invokeOnCancellation {
                            Log.d("CUSTOM-LOGS", "-----------> UNREGISTERING CALLBACK")
                            connManager.unregisterNetworkCallback(callback)
                        }
                    } else {
                        Log.d("CUSTOM-LOGS", "NativeHttpClient: network is null")
                        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE)
                                as ConnectivityManager

                        val network: Network? = cm.activeNetwork
                        if (network != null) {
                            cont.resume(network)
                        } else {
                            cont.resumeWithException(kotlin.IllegalStateException("no network found"))

                        }
                    }

                } catch (e: Exception) {
                    Log.e("NativeHttpClient", "Error", e)
                    cont.resumeWithException(e)
                }
            }
        }

    suspend fun send(
        request: HttpRequest,
    ) = withContext(Dispatchers.IO) {

        Log.d("CUSTOM-LOGS", "acquiring")
        try {
            val network = acquireNetwork(request.network)
            sendRequest(network, request)
        } catch (e: Exception) {
            emitErrorToFlutter(
                "${e::class.simpleName}",
                e.message,
                ""
            )
        }
    }
}