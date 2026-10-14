// SPDX-License-Identifier: Apache-2.0
package jp.lycorp.tritonkit.bridge.server

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class BridgeRequestDispatcherTest {
    @Test fun pingRunsWhenUiSlotsAreBlockedAndExcessUiIsRejected() {
        val dispatcher = BridgeRequestDispatcher(uiWorkers = 1, diagnosticWorkers = 1)
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val ping = CountDownLatch(1)
        val rejected = CountDownLatch(1)
        val repeated = AtomicInteger()
        try {
            dispatcher.submit(false, { entered.countDown(); release.await() }, { fail("first request rejected") })
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            dispatcher.submit(false, { repeated.incrementAndGet() }, { rejected.countDown() })
            dispatcher.submit(true, { ping.countDown() }, { fail("ping rejected") })
            assertTrue(rejected.await(2, TimeUnit.SECONDS))
            assertTrue(ping.await(2, TimeUnit.SECONDS))
            assertEquals(0, repeated.get())
        } finally { release.countDown(); dispatcher.close() }
    }
}
