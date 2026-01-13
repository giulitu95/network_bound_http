package com.faespa.network_bound_http_android.models

import com.faespa.network_bound_http_android.NetworkType
import io.flutter.plugin.common.MethodCall

data class NativeRequest(
    val url: String,
    val method: String,
    val networkType: NetworkType,
    val headers: Map<String, String>,
    val body: ByteArray?,
    val timeoutMs: Int
) {
    companion object {
        fun from(call: MethodCall): NativeRequest {
            return NativeRequest(
                url = call.argument("url")!!,
                method = call.argument("method")!!,
                networkType = NetworkType.valueOf(
                    (call.argument<String>("network")!!).uppercase()
                ),
                headers = call.argument("headers") ?: emptyMap(),
                body = call.argument("body"),
                timeoutMs = call.argument("timeoutMs") ?: 30000
            )
        }
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as NativeRequest

        if (timeoutMs != other.timeoutMs) return false
        if (url != other.url) return false
        if (method != other.method) return false
        if (networkType != other.networkType) return false
        if (headers != other.headers) return false
        if (!body.contentEquals(other.body)) return false

        return true
    }

    override fun hashCode(): Int {
        var result = timeoutMs
        result = 31 * result + url.hashCode()
        result = 31 * result + method.hashCode()
        result = 31 * result + networkType.hashCode()
        result = 31 * result + headers.hashCode()
        result = 31 * result + (body?.contentHashCode() ?: 0)
        return result
    }
}