package com.faespa.network_bound_http_android

import io.flutter.plugin.common.MethodCall

data class HttpRequest(
    val id: String,
    val uri: String,
    val method: String,
    val network: CustomNetwork,
    val headers: Map<String, String>,
    val body: ByteArray?,
    val timeout: Int,
    val outputPath: String,
) {
    companion object {
        fun from(call: MethodCall): HttpRequest {
            return HttpRequest(

                id = call.argument("id")!!,
                uri = call.argument("uri")!!,
                method = call.argument("method")!!,
                headers = call.argument("headers") ?: emptyMap(),
                body = call.argument("body"),
                timeout = call.argument("timeout") ?: 30000,
                network = CustomNetwork.valueOf(
                    (call.argument<String>("network")!!).uppercase()
                ),
                outputPath = call.argument("outputPath")!!
            )
        }
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as HttpRequest

        if (timeout != other.timeout) return false
        if (id != other.id) return false
        if (uri != other.uri) return false
        if (method != other.method) return false
        if (network != other.network) return false
        if (headers != other.headers) return false
        if (!body.contentEquals(other.body)) return false

        return true
    }

    override fun hashCode(): Int {
        var result = timeout
        result = 31 * result + id.hashCode()
        result = 31 * result + uri.hashCode()
        result = 31 * result + method.hashCode()
        result = 31 * result + network.hashCode()
        result = 31 * result + headers.hashCode()
        result = 31 * result + (body?.contentHashCode() ?: 0)
        return result
    }

}