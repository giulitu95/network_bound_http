package com.faespa.network_bound_http_android

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class NetworkBoundHttpAndroidPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private var eventSink: EventChannel.EventSink? = null

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        methodChannel = MethodChannel(
            binding.binaryMessenger,
            "network_bound_http/methods"
        )

        eventChannel = EventChannel(
            binding.binaryMessenger,
            "network_bound_http/events"
        )

        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        scope.cancel()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sendRequest" -> sendRequest(call, result)
            else -> result.notImplemented()
        }
    }

    private suspend fun emitToFlutter(
        eventSink: EventChannel.EventSink,
        payload: Map<String, Any?>
    ) = withContext(Dispatchers.Main) {
        eventSink.success(payload)
    }

    private fun sendRequest(call: MethodCall, result: MethodChannel.Result) {
        Log.d("CUSTOM-LOGS", "sending request 1")
        val request = HttpRequest.from(call)
        val sink = eventSink
        if (sink == null) {
            result.error("NO_LISTENER", "No EventChannel listener", null)
            return
        }

        result.success(null) // The response is handled through an evnet channel

        scope.launch {
            Log.d("CUSTOM-LOGS", "sending request 2")
            try {
                NativeHttpClient(context = context, eventSink = sink).send(request)
            } catch (e: Exception) {
                Log.d("CUSTOM-LOGS", "error while acquiring network")
                emitToFlutter(
                    sink,
                    mapOf(
                        "id" to request.id,
                        "type" to "error",
                        "message" to ("Exception while acquiring network: ${e.message}")
                    )
                )
            }
        }
    }
}
