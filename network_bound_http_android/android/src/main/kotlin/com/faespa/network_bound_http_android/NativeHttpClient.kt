package com.faespa.network_bound_http_android


import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlin.compareTo
import kotlin.io.inputStream
import kotlin.io.outputStream

class NativeHttpClient(private val context: Context, private val scope: CoroutineScope) {
    private suspend fun emit(
        eventSink: EventChannel.EventSink,
        payload: Map<String, Any?>
    ) = withContext(Dispatchers.Main) {
        eventSink.success(payload)
    }

    private suspend fun sendRequest(connection: HttpURLConnection, request: HttpRequest, eventSink: EventChannel.EventSink){
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
        Log.d("CUSTOM-LOGS", "NativeHttpClient: 3")
        val status = connection.responseCode
        Log.d("CUSTOM-LOGS", "NativeHttpClient: 4")

        val stream: InputStream? = if (status >= 400) connection.errorStream else connection.inputStream

        Log.d("CUSTOM-LOGS", "NativeHttpClient: status: $status")
        val file = File(request.outputPath)
        stream?.use {
            input -> FileOutputStream(file).use {
                output ->
                    Log.d("CUSTOM-LOGS", "NativeHttpClient: new stream event")
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var bytesRead: Int
                    var downloaded: Long = 0
                    val total = connection.contentLengthLong
                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        output.write(buffer, 0, bytesRead)
                        downloaded += bytesRead
                        Log.d("CUSTOM-LOGS", "NativeHttpClient: Sending progress")
                        emit(
                            eventSink,
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
        val headersMap: Map<String, String> = connection.headerFields
                .filterKeys { it != null } // rimuove la status line
                .map { (key, values) ->
                    key!! to values.joinToString(", ")
                }
                .toMap()

            emit(
                eventSink,
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
    suspend fun execute(
        request: HttpRequest,
        eventSink: EventChannel.EventSink
    ) = withContext(Dispatchers.IO) {

        Log.d("CUSTOM-LOGS", "NativeHttpClient: Sending request")
        try {
            val uri = URL(request.uri)
            if (request.network != CustomNetwork.ANY) {
                Log.d("CUSTOM-LOGS", "NativeHttpClient: network NOT null")
                val connManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                val netRequest = NetworkRequest.Builder()
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    .addTransportType(
                        when (request.network) {
                            CustomNetwork.WIFI -> NetworkCapabilities.TRANSPORT_WIFI
                            CustomNetwork.CELLULAR -> NetworkCapabilities.TRANSPORT_CELLULAR
                            else -> NetworkCapabilities.TRANSPORT_WIFI // it should never reach here
                        }
                    )
                    .build()
                val callback = object : ConnectivityManager.NetworkCallback() {
                    override fun onAvailable(network: Network) {
                        scope.launch{
                            Log.d("CUSTOM-LOGS", "NetworkSelector: network is available");
                            val connection = network.openConnection(uri) as HttpURLConnection
                            connection.requestMethod = request.method
                            sendRequest(connection = connection, request = request, eventSink = eventSink)
                        }
                    }

                    override fun onUnavailable() {
                        Log.d("CUSTOM-LOGS", "NetworkSelector: network is not available");
                    }
                }
                connManager.requestNetwork(netRequest, callback)
            } else {
                Log.d("CUSTOM-LOGS", "NativeHttpClient: network is null")
                val connection = uri.openConnection() as HttpURLConnection
                sendRequest(connection = connection, request = request, eventSink = eventSink)

            }


        } catch (e: Exception) {
            Log.e("NativeHttpClient", "Error", e)
            emit(
                eventSink,
                mapOf(
                    "id" to request.id,
                    "type" to "error",
                    "message" to (e.message ?: "Error while sending request ${request.id}")
                )
            )
        }
    }
}