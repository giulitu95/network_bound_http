package com.faespa.network_bound_http_android

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkRequest
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.eq
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.doNothing
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class NetworkSelectorTest {

    private val fakeNetworkReqFactory = mock<NetworkRequestFactory>()
    private val fakeContext = mock<Context>()
    private val connManager = mock<ConnectivityManager>()

    private val netRequest = mock<NetworkRequest>()

    private val fakeNetwork = mock<Network>()

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun `cellular network correctly acquired`() = runTest {
        val customNetwork = CustomNetwork.CELLULAR
        val callbackCaptor =
            argumentCaptor<ConnectivityManager.NetworkCallback>()


        whenever(fakeContext.getSystemService(Context.CONNECTIVITY_SERVICE)).thenReturn(connManager)
        whenever(fakeNetworkReqFactory.create(customNetwork)).thenReturn(netRequest)
        doNothing().`when`(
            connManager
        ).requestNetwork(
            eq(netRequest),
            any<ConnectivityManager.NetworkCallback>()
        )

        whenever(connManager.unregisterNetworkCallback(any<ConnectivityManager.NetworkCallback>())).thenAnswer { }


        val netSelector = DefaultNetworkSelector(
            fakeContext, customNetwork, fakeNetworkReqFactory
        )
        val deferred = async {
            netSelector.acquireNetwork()
        }
        runCurrent()
        verify(connManager).requestNetwork(eq(netRequest), callbackCaptor.capture())
        callbackCaptor.firstValue.onAvailable(fakeNetwork)
        val result = deferred.await()

        assertTrue { result == fakeNetwork }

    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun `cellular network not available`() = runTest {
        val customNetwork = CustomNetwork.CELLULAR
        val callbackCaptor =
            argumentCaptor<ConnectivityManager.NetworkCallback>()

        whenever(fakeContext.getSystemService(Context.CONNECTIVITY_SERVICE)).thenReturn(connManager)
        whenever(fakeNetworkReqFactory.create(customNetwork)).thenReturn(netRequest)
        doNothing().`when`(
            connManager
        ).requestNetwork(
            eq(netRequest),
            any<ConnectivityManager.NetworkCallback>()
        )

        whenever(connManager.unregisterNetworkCallback(any<ConnectivityManager.NetworkCallback>())).thenAnswer { }


        val netSelector = DefaultNetworkSelector(
            fakeContext, customNetwork, fakeNetworkReqFactory
        )
        var caughtException: Throwable? = null
        val job = launch {
            try {
                netSelector.acquireNetwork()
            } catch (e: Throwable) {
                caughtException = e
            }
        }
        runCurrent()
        verify(connManager).requestNetwork(eq(netRequest), callbackCaptor.capture())
        callbackCaptor.firstValue.onUnavailable()
        advanceUntilIdle()
        job.join()
        assertNotNull(caughtException)
        assertTrue(caughtException is IllegalStateException)
        assertEquals("Network is not available", caughtException?.message)


    }

    @Test
    fun `retrieves standard network`() = runTest {
        whenever(fakeContext.getSystemService(Context.CONNECTIVITY_SERVICE)).thenReturn(connManager)
        whenever(connManager.activeNetwork).thenReturn(fakeNetwork)

        val selector = DefaultNetworkSelector(fakeContext, CustomNetwork.STANDARD)
        val network = selector.acquireNetwork()

        assertEquals(network, fakeNetwork)
    }

    @Test
    fun `getting no available standard network`() = runTest {
        whenever(fakeContext.getSystemService(Context.CONNECTIVITY_SERVICE)).thenReturn(connManager)
        whenever(connManager.activeNetwork).thenReturn(null)

        val selector = DefaultNetworkSelector(fakeContext, CustomNetwork.STANDARD)
        val exception = assertFailsWith<IllegalStateException> {
            selector.acquireNetwork()
        }
        assertEquals("No default network found", exception.message)

    }

    @Test
    fun `random exception thrown trying acquire network`() = runTest {
        val thrownException = IllegalStateException()
        whenever(fakeContext.getSystemService(Context.CONNECTIVITY_SERVICE)).thenThrow(
            thrownException
        )

        val selector = DefaultNetworkSelector(fakeContext, CustomNetwork.STANDARD)
        assertFailsWith<IllegalStateException> {
            selector.acquireNetwork()
        }

    }

    @Test
    fun `acquireNetwork times out if network never available`() = runTest {
        val customNetwork = CustomNetwork.CELLULAR
        whenever(fakeContext.getSystemService(Context.CONNECTIVITY_SERVICE)).thenReturn(connManager)
        whenever(fakeNetworkReqFactory.create(customNetwork)).thenReturn(netRequest)

        doNothing().whenever(connManager)
            .requestNetwork(any(), any<ConnectivityManager.NetworkCallback>())
        val selector =
            DefaultNetworkSelector(fakeContext, CustomNetwork.CELLULAR, fakeNetworkReqFactory)
        assertFailsWith<TimeoutCancellationException> {
            selector.acquireNetwork(timeout = 500)
        }

    }

}