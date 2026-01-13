package com.faespa.network_bound_http_android


import android.net.ConnectivityManager
import android.net.Network
import android.util.Log
import com.faespa.network_bound_http_android.models.NativeRequest
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
class NativeHttpClient {

    suspend fun execute(
        network: Network?,
        request: NativeRequest,
        eventSink: EventChannel.EventSink
    ) = withContext(Dispatchers.IO) {

        try {
            val url = URL(request.url)
            val connection = if (network != null) {
                network.openConnection(url)
            } else {
                url.openConnection()
            } as HttpURLConnection

            connection.requestMethod = request.method
            connection.connectTimeout = request.timeoutMs
            connection.readTimeout = request.timeoutMs

            request.headers.forEach { (k, v) ->
                connection.setRequestProperty(k, v)
            }

            if (request.body != null) {
                connection.doOutput = true
                connection.outputStream.use { it.write(request.body) }
            }

            val status = connection.responseCode
            val stream: InputStream? = if (status >= 400) connection.errorStream else connection.inputStream
            val total = connection.contentLengthLong

            val buffer = ByteArray(8 * 1024) // 8KB
            var bytesRead: Int
            var downloaded = 0L

            stream?.use { input ->
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    downloaded += bytesRead

                    // Invia evento progress
                    eventSink.success(
                        mapOf(
                            "type" to "progress",
                            "downloaded" to downloaded,
                            "total" to total
                        )
                    )
                }
            }

            val headers = connection.headerFields
                .filterKeys { it != null }
                .mapValues { it.value.joinToString(",") }

            eventSink.success(
                mapOf(
                    "type" to "complete",
                    "statusCode" to status,
                    "headers" to headers
                )
            )

        } catch (e: Exception) {
            Log.e("NativeHttpClient", "Error", e)
            eventSink.success(
                mapOf(
                    "type" to "error",
                    "message" to (e.message ?: "Unknown error")
                )
            )
        }
    }
}