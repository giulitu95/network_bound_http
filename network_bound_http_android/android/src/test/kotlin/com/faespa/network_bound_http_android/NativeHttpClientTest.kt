package com.faespa.network_bound_http_android

import android.content.Context
import android.net.Network
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions
import org.junit.jupiter.api.BeforeEach
import org.mockito.ArgumentMatchers.any
import org.mockito.Mockito.doAnswer
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import java.io.ByteArrayInputStream
import java.io.InputStream
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.net.UnknownHostException
import kotlin.coroutines.ContinuationInterceptor
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
    private val fakeNetwork = mock(Network::class.java)
    private val fakeBody = "response data".toByteArray()
    private val uri = "https://www.uri.it"
    private val outputStream = mock<OutputStream>()
    private val fakeEventSink = mock<EventChannel.EventSink>()
    private val fakeConnection = mock(HttpURLConnection::class.java)
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
        val testDispatcher = coroutineContext[ContinuationInterceptor] as TestDispatcher
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

        `when`(fakeNetSelector.acquireNetwork(timeout.toLong())).thenReturn(fakeNetwork)
        `when`(fakeConnection.inputStream).thenReturn(inputStream)
        `when`(fakeConnection.responseCode).thenReturn(200)
        `when`(fakeConnection.outputStream).thenReturn(outputStream)
        `when`(fakeConnection.connect()).thenAnswer { /* do nothing*/ }
        `when`(fakeNetwork.openConnection(URL(uri))).thenReturn(fakeConnection)
        doAnswer { invocation ->
            val payload = invocation.getArgument<Map<String, Any?>>(0)
            successEvents.add(payload)
            null
        }.`when`(fakeEventSink).success(any())

        doAnswer { invocation ->
            errorEvents.add(
                Triple(
                    invocation.getArgument(0),
                    invocation.getArgument(1),
                    invocation.getArgument(2),
                )
            )
            null
        }.`when`(fakeEventSink).error(any(), any(), any())
        val client =
            NativeHttpClient(fakeContext, fakeEventSink, mainDispatcher = testDispatcher)
        client.send(request, fakeNetSelector)

        verify(fakeNetSelector).acquireNetwork(timeout.toLong())
        verify(fakeConnection).setRequestMethod(method)
        verify(fakeConnection).setConnectTimeout(timeout)
        verify(fakeConnection).setReadTimeout(timeout)
        verify(fakeConnection).setRequestProperty("key", "value")
        verify(fakeConnection).setDoOutput(true)

        Assertions.assertTrue(successEvents.isNotEmpty())
        Assertions.assertFalse(successEvents.find { e -> e["type"] == "progress" }.isNullOrEmpty())
        Assertions.assertFalse(successEvents.find { e -> e["type"] == "complete" && e["statusCode"] == 200 }
            .isNullOrEmpty())
        Assertions.assertTrue(errorEvents.isEmpty())
    }

    @Test
    fun send_request_default_network_ok_400() = runTest {
        val testDispatcher = coroutineContext[ContinuationInterceptor] as TestDispatcher
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
        `when`(fakeNetSelector.acquireNetwork(timeout.toLong())).thenReturn(fakeNetwork)
        `when`(fakeConnection.errorStream).thenReturn(inputStream)
        `when`(fakeConnection.responseCode).thenReturn(400)
        `when`(fakeConnection.outputStream).thenReturn(outputStream)
        `when`(fakeConnection.connect()).thenAnswer { /* do nothing*/ }
        `when`(fakeNetwork.openConnection(URL(uri))).thenReturn(fakeConnection)
        doAnswer { invocation ->
            val payload = invocation.getArgument<Map<String, Any?>>(0)
            successEvents.add(payload)
            null
        }.`when`(fakeEventSink).success(any())

        doAnswer { invocation ->
            errorEvents.add(
                Triple(
                    invocation.getArgument(0),
                    invocation.getArgument(1),
                    invocation.getArgument(2),
                )
            )
            null
        }.`when`(fakeEventSink).error(any(), any(), any())
        val client =
            NativeHttpClient(fakeContext, fakeEventSink, mainDispatcher = testDispatcher)
        client.send(request, fakeNetSelector)

        verify(fakeNetSelector).acquireNetwork(timeout.toLong())
        verify(fakeConnection).setRequestMethod(method)
        verify(fakeConnection).setConnectTimeout(timeout)
        verify(fakeConnection).setReadTimeout(timeout)
        verify(fakeConnection).setRequestProperty("key", "value")
        verify(fakeConnection).setDoOutput(true)

        Assertions.assertTrue(successEvents.isNotEmpty())
        Assertions.assertFalse(successEvents.find { e -> e["type"] == "progress" }.isNullOrEmpty())
        Assertions.assertFalse(successEvents.find { e -> e["type"] == "complete" && e["statusCode"] == 400 }
            .isNullOrEmpty())
        Assertions.assertTrue(errorEvents.isEmpty())
    }

    // This is the case in which a network without internet connection is used
    @Test
    fun unknown_host_exception() = runTest {
        val testDispatcher = coroutineContext[ContinuationInterceptor] as TestDispatcher
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

        `when`(fakeNetSelector.acquireNetwork(timeout.toLong())).thenReturn(fakeNetwork)
        `when`(fakeNetwork.openConnection(URL(uri))).thenReturn(fakeConnection)
        `when`(fakeConnection.connect()).thenThrow(exception)
        doAnswer { invocation ->
            val payload = invocation.getArgument<Map<String, Any?>>(0)
            successEvents.add(payload)
            null // funzione void -> ritorna null
        }.`when`(fakeEventSink).success(any())

        doAnswer { invocation ->
            errorEvents.add(
                Triple(
                    invocation.getArgument(0),
                    invocation.getArgument(1),
                    invocation.getArgument(2),
                )
            )
            null // funzione void -> ritorna null
        }.`when`(fakeEventSink).error(any(), any(), any())
        val client =
            NativeHttpClient(fakeContext, fakeEventSink, mainDispatcher = testDispatcher)
        client.send(request, fakeNetSelector)

        verify(fakeNetSelector).acquireNetwork(timeout.toLong())
        verify(fakeConnection).setRequestMethod(method)
        verify(fakeConnection).setConnectTimeout(timeout)
        verify(fakeConnection).setReadTimeout(timeout)
        verify(fakeConnection).setRequestProperty("key", "value")
        verify(fakeConnection).setDoOutput(true)

        Assertions.assertTrue(successEvents.isEmpty())
        Assertions.assertTrue(errorEvents.isNotEmpty())
        Assertions.assertTrue(errorEvents.find { e -> e.first == "UnknownHostException" && e.second == exception.message && e.third == "" } == null)
    }

    /*
    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun `acquireNetwork times out if network never available`() = runTest {

        val testDispatcher = coroutineContext[ContinuationInterceptor] as TestDispatcher
        val request = HttpRequest(
            id = id,
            uri = uri,
            method = method,
            network = CustomNetwork.WIFI,
            headers = headers,
            body = body,
            timeout = timeout,
            outputPath = outputPath
        )
        `when`(fakeContext.getSystemService(Context.CONNECTIVITY_SERVICE)).thenReturn(
            connectivityManager
        )
        doNothing().`when`(connectivityManager)
            .requestNetwork(any(), any<ConnectivityManager.NetworkCallback>())
        doAnswer { invocation ->
            val payload = invocation.getArgument<Map<String, Any?>>(0)
            successEvents.add(payload)
            null // funzione void -> ritorna null
        }.`when`(fakeEventSink).success(any())

        doAnswer { invocation ->
            errorEvents.add(
                Triple(
                    invocation.getArgument(0),
                    invocation.getArgument(1),
                    invocation.getArgument(2),
                )
            )
            null // funzione void -> ritorna null
        }.`when`(fakeEventSink).error(any(), any(), any())

        val client =
            NativeHttpClient(fakeContext, fakeEventSink, mainDispatcher = testDispatcher)
        client.send(request)
        /*
        val exception = assertThrows<TimeoutCancellationException> {
            client.acquireNetwork(CustomNetwork.WIFI, timeout = 500)
        }

        assertTrue(errorEvents.find { e -> e.first == "TimeoutCancellationException" && e.second == exception.message && e.third == "" } == null)
    */


    }*/

}
