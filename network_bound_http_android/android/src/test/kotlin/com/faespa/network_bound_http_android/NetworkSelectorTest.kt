package com.faespa.network_bound_http_android

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkRequest
import kotlinx.coroutines.ExperimentalCoroutinesApi
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
    fun `cellular network corrdectly acquired`() = runTest {
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
}