package com.faespa.network_bound_http_android

import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class ChannelHelper(
    private val eventSink: EventChannel.EventSink,
    private val mainDispatcher: CoroutineDispatcher = Dispatchers.Main
) {
    suspend fun emitToFlutter(
        payload: Map<String, Any?>
    ) = withContext(mainDispatcher) {
        eventSink.success(payload)
    }

    suspend fun emitErrorToFlutter(
        errorCode: String,
        errorMessage: String?,
        errorDetails: String?
    ) = withContext(mainDispatcher) {
        eventSink.error(errorCode, errorMessage, errorDetails)
    }
}