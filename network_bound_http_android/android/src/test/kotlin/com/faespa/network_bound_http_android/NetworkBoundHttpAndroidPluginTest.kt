package com.faespa.network_bound_http_android

import android.content.Context
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import org.mockito.kotlin.any
import org.mockito.kotlin.doNothing
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.spy
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import kotlin.test.Test

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

internal class NetworkBoundHttpAndroidPluginTest {
    private val fakeChannelHelper = mock<ChannelHelper>()
    private val fakeEventSink = mock<EventChannel.EventSink>()

    private val fakeContext = mock<Context>()

    private val fakeClient = mock<NativeHttpClient>()
    val fakeResult = mock<MethodChannel.Result>()
    private val testDispatcher = StandardTestDispatcher()

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun `if a methodCall 'sendRequest' with the correct args are passed sendRequest is called`() {
        val mockedPlugin = spy(NetworkBoundHttpAndroidPlugin())
        mockedPlugin.eventSink = fakeEventSink
        mockedPlugin.context = fakeContext
        mockedPlugin.clientFactory = { _, _ -> fakeClient }
        mockedPlugin.channelHelperFactory = { _ -> fakeChannelHelper }


        val call = MethodCall(
            "sendRequest", mapOf(
                "id" to "id",
                "uri" to "uri",
                "method" to "method",
                "network" to "standard",
                "outputPath" to "outputPath"

            )
        )
        doNothing().whenever(mockedPlugin)
            .sendRequest(
                any<MethodCall>(),
                any<MethodChannel.Result>(),
                eq(fakeClient)
            )

        mockedPlugin.onMethodCall(call, fakeResult)

        verify(mockedPlugin).sendRequest(call, fakeResult, fakeClient)

    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun `if event sink is null, method call `() {
        val mockedPlugin = spy(NetworkBoundHttpAndroidPlugin())
        mockedPlugin.context = fakeContext


        val call = MethodCall(
            "sendRequest", mapOf(
                "id" to "id",
                "uri" to "uri",
                "method" to "method",
                "network" to "standard",
                "outputPath" to "outputPath"

            )
        )
        mockedPlugin.onMethodCall(call, fakeResult)

        verify(fakeResult).error("NO_LISTENER", "No EventChannel listener", null)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun `return notImplemented if a not-valid method is called `() {
        val mockedPlugin = spy(NetworkBoundHttpAndroidPlugin())
        mockedPlugin.context = fakeContext
        mockedPlugin.eventSink = fakeEventSink


        val call = MethodCall(
            "not valid method", ""
        )
        mockedPlugin.onMethodCall(call, fakeResult)

        verify(fakeResult).notImplemented()
    }


}
