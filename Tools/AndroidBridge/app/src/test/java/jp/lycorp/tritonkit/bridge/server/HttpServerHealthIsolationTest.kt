// SPDX-License-Identifier: Apache-2.0
package jp.lycorp.tritonkit.bridge.server

import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.*
import org.junit.Test
import java.net.Socket
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Socket-path fixture: the real server must route ping while all UI handler slots are occupied. */
class HttpServerHealthIsolationTest {
    @Test fun pingRemainsReachableAndExcessWriteDoesNotExecute() {
        val blocked = CountDownLatch(4)
        val release = CountDownLatch(1)
        val router = mockk<ActionRouter>()
        every { router.route("GET", "/a11y_tree_full", any(), any()) } answers {
            blocked.countDown()
            release.await()
            HttpResponse(200, "{}")
        }
        every { router.route("GET", "/ping", any(), any()) } returns HttpResponse(200, "{\"result\":\"pong\"}")
        val server = HttpServer(0, router)
        val sockets = mutableListOf<Socket>()
        try {
            server.start()
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
            while (server.listeningPort == null && System.nanoTime() < deadline) Thread.yield()
            val port = server.listeningPort ?: error("server did not bind")
            repeat(4) { sockets.add(request(port, "GET", "/a11y_tree_full")) }
            assertTrue(blocked.await(2, TimeUnit.SECONDS))
            request(port, "GET", "/ping").use { ping ->
                val response = ping.getInputStream().bufferedReader().readText()
                assertTrue(response.startsWith("HTTP/1.1 200"))
                assertTrue(response.contains("pong"))
            }
            request(port, "POST", "/tap").use { write ->
                val response = write.getInputStream().bufferedReader().readText()
                assertTrue(response.startsWith("HTTP/1.1 503"))
                assertTrue(response.contains("not_started"))
            }
            io.mockk.verify(exactly = 0) { router.route("POST", "/tap", any(), any()) }
        } finally {
            release.countDown()
            sockets.forEach { it.close() }
            server.stop()
        }
    }

    private fun request(port: Int, method: String, path: String): Socket = Socket("127.0.0.1", port).apply {
        soTimeout = 2_000
        getOutputStream().write("$method $path HTTP/1.1\r\nHost: localhost\r\n\r\n".toByteArray())
        getOutputStream().flush()
    }
}
