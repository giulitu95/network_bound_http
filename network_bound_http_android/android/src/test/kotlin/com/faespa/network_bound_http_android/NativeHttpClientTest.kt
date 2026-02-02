package com.faespa.network_bound_http_android

import android.content.Context
import android.net.Network
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions
import org.junit.jupiter.api.BeforeEach
import org.mockito.kotlin.any
import org.mockito.kotlin.doAnswer
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import java.io.ByteArrayInputStream
import java.io.InputStream
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.net.UnknownHostException
import kotlin.test.Test

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

@OptIn(ExperimentalCoroutinesApi::class)
class NativeHttpClientTest {
    private val id = "id"
    private val method = "method"
    private val network = CustomNetwork.STANDARD
    private val headers = mapOf("key" to "value")
    private val body = ByteArray(10)
    private val timeout = 500
    private val outputPath = "outputPath"
    private val fakeContext = mock<Context>()
    private val fakeNetwork = mock<Network>()
    private val fakeBody = "response data".toByteArray()
    private val uri = "https://www.uri.it"
    private val outputStream = mock<OutputStream>()
    private val fakeChannelHelper = mock<ChannelHelper>()
    private val fakeConnection = mock<HttpURLConnection>()
    private var successEvents = mutableListOf<Map<String, Any?>>()
    private var errorEvents = mutableListOf<Triple<String, String, String>>()
    private val fakeNetSelector = mock<NetworkSelector>()


    @BeforeEach
    fun `init tests`() {
        successEvents = mutableListOf()
        errorEvents = mutableListOf()
    }


    @Test
    fun send_request_default_network_ok_200() = runTest {
        val request = HttpRequest(
            id = id,
            uri = uri,
            method = method,
            network = network,
            headers = headers,
            body = body,
            timeout = timeout,
            outputPath = outputPath
        )
        val inputStream: InputStream = ByteArrayInputStream(fakeBody)

        whenever(fakeNetSelector.acquireNetwork(timeout.toLong())).thenReturn(fakeNetwork)
        whenever(fakeConnection.inputStream).thenReturn(inputStream)
        whenever(fakeConnection.responseCode).thenReturn(200)
        whenever(fakeConnection.outputStream).thenReturn(outputStream)
        whenever(fakeConnection.connect()).thenAnswer { /* do nothing*/ }
        whenever(fakeNetwork.openConnection(URL(uri))).thenReturn(fakeConnection)
        doAnswer { invocation ->
            val payload = invocation.getArgument<Map<String, Any?>>(0)
            successEvents.add(payload)
            null
        }.whenever(fakeChannelHelper).emitToFlutter(any())

        doAnswer { invocation ->
            errorEvents.add(
                Triple(
                    invocation.getArgument(0),
                    invocation.getArgument(1),
                    invocation.getArgument(2),
                )
            )
            null
        }.whenever(fakeChannelHelper).emitErrorToFlutter(any(), any(), any())
        val client =
            NativeHttpClient(fakeContext, fakeChannelHelper)
        client.send(request, fakeNetSelector)

        verify(fakeNetSelector).acquireNetwork(timeout.toLong())
        verify(fakeConnection).setRequestMethod(method)
        verify(fakeConnection).setConnectTimeout(timeout)
        verify(fakeConnection).setRequestProperty("key", "value")
        verify(fakeConnection).setDoOutput(true)

        Assertions.assertTrue(successEvents.isNotEmpty())
        Assertions.assertFalse(successEvents.find { e -> e["type"] == "progress" }.isNullOrEmpty())
        Assertions.assertFalse(successEvents.find { e -> e["type"] == "done" }.isNullOrEmpty())
        Assertions.assertFalse(successEvents.find { e -> e["type"] == "status" && e["statusCode"] == 200 }
            .isNullOrEmpty())
        Assertions.assertTrue(errorEvents.isEmpty())
    }

    @Test
    fun send_request_default_network_ok_400() = runTest {
        val request = HttpRequest(
            id = id,
            uri = uri,
            method = method,
            network = network,
            headers = headers,
            body = body,
            timeout = timeout,
            outputPath = outputPath
        )
        val inputStream: InputStream = ByteArrayInputStream(fakeBody)
        whenever(fakeNetSelector.acquireNetwork(timeout.toLong())).thenReturn(fakeNetwork)
        whenever(fakeConnection.errorStream).thenReturn(inputStream)
        whenever(fakeConnection.responseCode).thenReturn(400)
        whenever(fakeConnection.outputStream).thenReturn(outputStream)
        whenever(fakeConnection.connect()).thenAnswer { /* do nothing*/ }
        whenever(fakeNetwork.openConnection(URL(uri))).thenReturn(fakeConnection)
        doAnswer { invocation ->
            val payload = invocation.getArgument<Map<String, Any?>>(0)
            successEvents.add(payload)
            null
        }.whenever(fakeChannelHelper).emitToFlutter(any())

        doAnswer { invocation ->
            errorEvents.add(
                Triple(
                    invocation.getArgument(0),
                    invocation.getArgument(1),
                    invocation.getArgument(2),
                )
            )
            null
        }.whenever(fakeChannelHelper).emitErrorToFlutter(any(), any(), any())
        val client =
            NativeHttpClient(fakeContext, fakeChannelHelper)
        client.send(request, fakeNetSelector)

        verify(fakeNetSelector).acquireNetwork(timeout.toLong())
        verify(fakeConnection).setRequestMethod(method)
        verify(fakeConnection).setConnectTimeout(timeout)
        verify(fakeConnection).setRequestProperty("key", "value")
        verify(fakeConnection).setDoOutput(true)

        Assertions.assertTrue(successEvents.isNotEmpty())
        Assertions.assertFalse(successEvents.find { e -> e["type"] == "progress" }.isNullOrEmpty())
        Assertions.assertFalse(successEvents.find { e -> e["type"] == "done" }.isNullOrEmpty())
        Assertions.assertFalse(successEvents.find { e -> e["type"] == "status" && e["statusCode"] == 400 }
            .isNullOrEmpty())
        Assertions.assertTrue(errorEvents.isEmpty())
    }

    // This is the case in which a network without internet connection is used
    @Test
    fun unknown_host_exception() = runTest {
        val request = HttpRequest(
            id = id,
            uri = uri,
            method = method,
            network = network,
            headers = headers,
            body = body,
            timeout = timeout,
            outputPath = outputPath
        )

        val exception = UnknownHostException()

        whenever(fakeNetSelector.acquireNetwork(timeout.toLong())).thenReturn(fakeNetwork)
        whenever(fakeNetwork.openConnection(URL(uri))).thenReturn(fakeConnection)
        whenever(fakeConnection.connect()).thenThrow(exception)
        doAnswer { invocation ->
            val payload = invocation.getArgument<Map<String, Any?>>(0)
            successEvents.add(payload)
            null // funzione void -> ritorna null
        }.whenever(fakeChannelHelper).emitToFlutter(any())

        doAnswer { invocation ->
            errorEvents.add(
                Triple(
                    invocation.getArgument(0),
                    invocation.getArgument(1),
                    invocation.getArgument(2),
                )
            )
            null // funzione void -> ritorna null
        }.whenever(fakeChannelHelper).emitErrorToFlutter(any(), any(), any())
        val client =
            NativeHttpClient(fakeContext, fakeChannelHelper)
        client.send(request, fakeNetSelector)

        verify(fakeNetSelector).acquireNetwork(timeout.toLong())
        verify(fakeConnection).setRequestMethod(method)
        verify(fakeConnection).setConnectTimeout(timeout)
        verify(fakeConnection).setRequestProperty("key", "value")
        verify(fakeConnection).setDoOutput(true)

        Assertions.assertTrue(successEvents.isEmpty())
        Assertions.assertTrue(errorEvents.isNotEmpty())
        Assertions.assertTrue(errorEvents.find { e -> e.first == "UnknownHostException" && e.second == exception.message && e.third == "" } == null)
    }


}
