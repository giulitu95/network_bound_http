package com.faespa.network_bound_http_android

import android.content.Context
import com.faespa.network_bound_http_android.models.NativeRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
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

    // -------------------------
    // FlutterPlugin
    // -------------------------

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

    // -------------------------
    // EventChannel.StreamHandler
    // -------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // -------------------------
    // MethodChannel handler
    // -------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startDownload" -> startDownload(call, result)
            else -> result.notImplemented()
        }
    }

    // -------------------------
    // Download logic
    // -------------------------

    private fun startDownload(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as Map<*, *>

        val url = args["url"] as String
        val networkType = NetworkType.valueOf(args["network"] as String)
        val timeoutMs = (args["timeoutMs"] as Int?) ?: 15000
        val outputPath = args["outputPath"] as String

        val sink = eventSink
        if (sink == null) {
            result.error("NO_LISTENER", "No EventChannel listener", null)
            return
        }

        result.success(null) // risposta immediata a Dart

        scope.launch {
            try {
                val selector = NetworkSelector(context)
                val network = selector.acquire(networkType, timeoutMs)

                val request = NativeRequest(
                    url = url,
                    method = "GET",
                    headers = emptyMap(),
                    body = null,
                    timeoutMs = timeoutMs,
                    networkType = networkType,
                )

                NativeHttpClient().execute(network, request, sink)

            } catch (e: Exception) {
                sink.success(
                    mapOf(
                        "type" to "error",
                        "message" to (e.message ?: "Unknown error")
                    )
                )
            }
        }
    }
}
