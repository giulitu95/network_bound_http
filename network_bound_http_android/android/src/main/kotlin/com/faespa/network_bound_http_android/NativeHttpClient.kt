package com.faespa.network_bound_http_android


import android.net.Network
import android.util.Log
import com.faespa.network_bound_http_android.HttpRequest
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
class NativeHttpClient {

    suspend fun execute(
        network: Network?,
        request: HttpRequest,
        eventSink: EventChannel.EventSink
    ) = withContext(Dispatchers.IO) {

        try {
            val uri = URL(request.uri)
            val connection = if (network != null) {
                network.openConnection(uri)
            } else {
                uri.openConnection()
            } as HttpURLConnection

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

            val status = connection.responseCode
            val stream: InputStream? = if (status >= 400) connection.errorStream else connection.inputStream

            val file = File(request.outputPath)
            stream?.use {
                input -> FileOutputStream(file).use {
                    output ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        var bytesRead: Int
                        var downloaded: Long = 0
                        val total = connection.contentLengthLong
                        while (input.read(buffer).also { bytesRead = it } != -1) {
                            output.write(buffer, 0, bytesRead)
                            downloaded += bytesRead
                            eventSink.success(
                                mapOf(
                                    "id" to "id",
                                    "type" to "progress",
                                    "downloaded" to downloaded,
                                    "total" to total
                                )
                            )
                        }
                }
            }

            val headersAsList: List<String> =
                connection.headerFields
                    .filterKeys { it != null } // status line (key = null)
                    .flatMap { (key, values) ->
                        values.map { value -> "$key: $value" }
                    }

            eventSink.success(
                mapOf(
                    "id" to request.id,
                    "type" to "complete",
                    "statusCode" to status,
                    "headers" to headersAsList,
                    "outputFile" to request.outputPath
                )
            )

        } catch (e: Exception) {
            Log.e("NativeHttpClient", "Error", e)
            eventSink.success(
                mapOf(
                    "id" to request.id,
                    "type" to "error",
                    "message" to (e.message ?: "Error while sending request ${request.id}")
                )
            )
        }
    }
}