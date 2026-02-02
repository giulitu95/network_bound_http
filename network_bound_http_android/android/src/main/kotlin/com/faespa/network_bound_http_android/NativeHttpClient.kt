package com.faespa.network_bound_http_android


import android.content.Context
import android.net.Network
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

class NativeHttpClient(
    private val context: Context,
    private val channelHelper: ChannelHelper
) {

    suspend fun sendRequest(
        network: Network,
        request: HttpRequest,
    ) {
        //Log.d("CUSTOM-LOGS", "sending request")
        val connection = network.openConnection(URL(request.uri)) as HttpURLConnection
        connection.requestMethod = request.method
        connection.connectTimeout = request.timeout
        request.headers.forEach { (k, v) ->
            connection.setRequestProperty(k, v)
        }
        if (request.body != null) {
            connection.doOutput = true
            connection.outputStream.use { it.write(request.body) }
        }
        connection.connect()
        val status = connection.responseCode


        val headersMap: Map<String, String> =
            connection.headerFields
                .filterKeys { it != null }
                .map { (key, values) ->
                    key!! to values.joinToString(", ")
                }
                .toMap()

        channelHelper.emitToFlutter(
            mapOf(
                "id" to request.id,
                "type" to "status",
                "statusCode" to status,
                "headers" to headersMap,
                "outputFile" to request.outputPath,
                "contentLength" to connection.contentLengthLong,
            )
        )


        val stream: InputStream? =
            if (status >= 400) connection.errorStream else connection.inputStream

        val file = File(request.outputPath)
        stream?.use { input ->
            FileOutputStream(file).use { output ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                var bytesRead: Int
                var downloaded: Long = 0
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                    downloaded += bytesRead
                    channelHelper.emitToFlutter(
                        mapOf(
                            "id" to request.id,
                            "type" to "progress",
                            "contentLength" to connection.contentLengthLong,
                            "downloaded" to downloaded,
                        )
                    )
                }
                channelHelper.emitToFlutter(
                    mapOf(
                        "id" to request.id,
                        "type" to "done",
                        "contentLength" to connection.contentLengthLong,
                        "downloaded" to downloaded,
                    )
                )
            }
        }
    }


    suspend fun send(
        request: HttpRequest,
        networkSelector: NetworkSelector = DefaultNetworkSelector(context, request.network)
    ) = withContext(Dispatchers.IO) {
        try {
            val network = networkSelector.acquireNetwork(request.timeout.toLong())
            sendRequest(network, request)
        } catch (e: Exception) {
            channelHelper.emitErrorToFlutter(
                "${request.id}::${e::class.simpleName}",
                e.message,
                ""
            )
        }
    }
}