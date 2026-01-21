package com.faespa.network_bound_http_android

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class NetworkBoundHttpAndroidPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    internal lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    internal var eventSink: EventChannel.EventSink? = null

    internal var clientFactory: (Context, ChannelHelper) -> NativeHttpClient = { ctx, helper ->
        NativeHttpClient(ctx, helper)
    }

    internal var channelHelperFactory: (EventChannel.EventSink) -> ChannelHelper =
        { eventSink ->
            ChannelHelper(eventSink)
        }


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
        if (eventSink == null) {
            result.error("NO_LISTENER", "No EventChannel listener", null)
            return
        }
        when (call.method) {
            "sendRequest" -> sendRequest(call, result)
            else -> result.notImplemented()
        }
    }

    internal fun sendRequest(
        call: MethodCall,
        result: MethodChannel.Result,
        client: NativeHttpClient = clientFactory(context, channelHelperFactory(eventSink!!))
    ) {

        val request = HttpRequest.from(call)
        result.success(null) // The response is handled through an evnet channel

        scope.launch {
            client.send(request)
        }
    }
}
