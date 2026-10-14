// SPDX-License-Identifier: Apache-2.0
package jp.lycorp.tritonkit.bridge.server

import java.io.Closeable
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.Semaphore
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

/** Diagnostic work never queues behind UI/Binder work. Saturation rejects before execution. */
internal class BridgeRequestDispatcher(uiWorkers: Int = 4, diagnosticWorkers: Int = 2) : Closeable {
    private val ui = pool(uiWorkers, "ui")
    private val diagnostic = pool(diagnosticWorkers, "diagnostic")
    private val uiAdmission = Semaphore(uiWorkers)
    private val diagnosticAdmission = Semaphore(diagnosticWorkers)

    fun submit(isDiagnostic: Boolean, work: () -> Unit, rejected: () -> Unit) {
        val admission = if (isDiagnostic) diagnosticAdmission else uiAdmission
        if (!admission.tryAcquire()) { rejected(); return }
        try {
            (if (isDiagnostic) diagnostic else ui).execute {
                try { work() } finally { admission.release() }
            }
        } catch (_: RejectedExecutionException) { admission.release(); rejected() }
    }

    override fun close() {
        // shutdownNow is best effort; an uninterruptible Binder call cannot be killed here.
        ui.shutdownNow()
        diagnostic.shutdownNow()
    }

    private fun pool(workers: Int, name: String) = ThreadPoolExecutor(
        workers, workers, 0L, TimeUnit.MILLISECONDS, ArrayBlockingQueue(workers),
        { task -> Thread(task, "TritonKitHttp-$name").apply { isDaemon = true } },
        ThreadPoolExecutor.AbortPolicy(),
    ).apply { prestartAllCoreThreads() }
}
