package com.faespa.network_bound_http_android

import android.content.Context
import com.faespa.network_bound_http_android.HttpRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlin.collections.emptyMap
import kotlin.collections.get

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

    private fun sendRequest(call: MethodCall, result: MethodChannel.Result) {
        val request = HttpRequest.from(call)
        val sink = eventSink
        if (sink == null) {
            result.error("NO_LISTENER", "No EventChannel listener", null)
            return
        }

        result.success(null) // risposta immediata a Dart

        scope.launch {
            try {
                val selector = NetworkSelector(context)
                val network = selector.acquire(network = request.network, timeout = request.timeout)
                NativeHttpClient().execute(network, request, sink)
            } catch (e: Exception) {
                sink.success(
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
