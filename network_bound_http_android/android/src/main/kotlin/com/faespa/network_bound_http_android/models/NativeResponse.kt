package com.faespa.network_bound_http_android.models

data class NativeResponse(
    val statusCode: Int,
    val headers: Map<String, String>,
    val body: ByteArray
) {
    fun toMap(): Map<String, Any> = mapOf(
        "statusCode" to statusCode,
        "headers" to headers,
        "body" to body.toList()
    )

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as NativeResponse

        if (statusCode != other.statusCode) return false
        if (headers != other.headers) return false
        if (!body.contentEquals(other.body)) return false

        return true
    }

    override fun hashCode(): Int {
        var result = statusCode
        result = 31 * result + headers.hashCode()
        result = 31 * result + body.contentHashCode()
        return result
    }
}
