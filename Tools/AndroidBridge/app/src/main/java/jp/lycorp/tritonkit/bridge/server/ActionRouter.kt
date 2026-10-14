// SPDX-License-Identifier: Apache-2.0
package jp.lycorp.tritonkit.bridge.server

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.util.Base64
import android.util.Log
import android.view.WindowManager
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import jp.lycorp.tritonkit.bridge.BuildConfig
import jp.lycorp.tritonkit.bridge.config.AuthManager
import jp.lycorp.tritonkit.bridge.handler.CaptureHandler
import jp.lycorp.tritonkit.bridge.handler.GestureHandler
import jp.lycorp.tritonkit.bridge.handler.InputHandler
import jp.lycorp.tritonkit.bridge.handler.KeyboardStateHandler
import jp.lycorp.tritonkit.bridge.handler.PasteHandler
import jp.lycorp.tritonkit.bridge.handler.TreeHandler
import jp.lycorp.tritonkit.bridge.handler.TreeCollectionBudget
import jp.lycorp.tritonkit.bridge.handler.TreeCollectionLimits
import jp.lycorp.tritonkit.bridge.model.ElementNode
import android.graphics.Rect
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicInteger

/**
 * HTTP request → handler dispatcher.
 *
 * Replicates csat's `ActionRouter` structure (Bearer auth, dispatch by
 * `(method, path)`, semaphore-guarded `rootInActiveWindow`, executor
 * with timeout). Our deviations from csat:
 *
 *  1. **Inline JSON `result`** — `result` is a real JSON value (string,
 *     object, array), NOT a JSON-encoded string. csat double-encodes;
 *     we don't. (Kickoff gotcha #1.)
 *  2. **`/ping` carries `protocol_version` + `bridge_version`** as
 *     envelope siblings of `status` / `result`. csat's `/ping` returns
 *     only `"pong"`.
 *  3. **`/keyboard/key` rejects unsupported keycodes** with a 400 and
 *     structured error pointing at `/keyboard/input`. csat broadcasts
 *     them to a custom IME; we don't ship one (Q5).
 */
class ActionRouter(
    private val serviceProvider: () -> AccessibilityService?,
    private val authManager: AuthManager,
    private val rootWindowTimeoutMillis: Long = ROOT_WINDOW_TIMEOUT_SECONDS * 1_000L,
    private val rootWindowWaitMillis: Long = ROOT_WINDOW_WAIT_SECONDS * 1_000L,
) {
    private val treeHandler = TreeHandler()
    private val captureHandler = CaptureHandler()
    private val gestureHandler = GestureHandler()
    private val inputHandler = InputHandler()
    private val keyboardStateHandler = KeyboardStateHandler()
    private val pasteHandler = PasteHandler()

    // Admission remains held until the actual Binder worker finishes, even if its
    // caller timed out. Interrupting a thread cannot guarantee Binder cancellation.
    private val rootWindowExecutor = Executors.newCachedThreadPool()
    // Concurrent rootInActiveWindow calls can deadlock the Binder IPC
    // path (csat confirmed on Samsung Galaxy + Gallery viewer). One in
    // flight at a time; waiters get 503 instead of hanging.
    private val rootWindowSemaphore = Semaphore(1)
    private val activeRootCalls = AtomicInteger(0)
    private val timeoutCount = AtomicInteger(0)
    private val totalRootCalls = AtomicInteger(0)
    private val activeUiRequests = AtomicInteger(0)

    fun route(
        method: String,
        path: String,
        params: Map<String, String>,
        headers: Map<String, String>,
    ): HttpResponse {
        if (path != "/ping" && !isAuthorized(headers)) {
            return HttpResponse(401, errorJson("unauthorized"))
        }
        val uiRequest = !(method == "GET" && path == "/ping")
        if (uiRequest) activeUiRequests.incrementAndGet()
        return try {
            dispatch(method, path, params)
        } catch (e: Exception) {
            Log.e(TAG, "Handler error for $method $path", e)
            HttpResponse(500, errorJson("internal_error", e.message))
        } finally {
            if (uiRequest) activeUiRequests.decrementAndGet()
        }
    }

    private fun dispatch(
        method: String,
        path: String,
        params: Map<String, String>,
    ): HttpResponse = when {
        method == "GET" && path == "/ping" -> handlePing()
        method == "GET" && path == "/screenshot" -> handleScreenshot()
        method == "GET" && path == "/a11y_tree_full" -> handleTree(params)
        method == "POST" && path == "/tap" -> handleTap(params)
        method == "POST" && path == "/swipe" -> handleSwipe(params)
        method == "POST" && path == "/gesture" -> handleGesture(params)
        method == "POST" && path == "/keyboard/input" -> handleInput(params)
        method == "POST" && path == "/keyboard/key" -> handleKey(params)
        method == "GET" && path == "/keyboard/state" -> handleKeyboardState()
        method == "POST" && path == "/paste" -> handlePaste(params)
        else -> HttpResponse(404, errorJson("unknown_endpoint"))
    }

    // ── Handlers ────────────────────────────────────────────────

    private fun handlePing(): HttpResponse {
        val payload = JSONObject().apply {
            put("status", "success")
            put("result", "pong")
            put("protocol_version", BuildConfig.PROTOCOL_VERSION)
            put("bridge_version", BuildConfig.VERSION_NAME)
            put("ui_health", JSONObject().apply {
                put("state", if (activeUiRequests.get() > 0 || activeRootCalls.get() > 0) "busy" else if (timeoutCount.get() > 0) "degraded" else "ready")
                put("active_requests", activeUiRequests.get())
                put("active_root_calls", activeRootCalls.get())
                put("root_timeouts", timeoutCount.get())
                put("hard_timeout_cancellable", false)
            })
        }
        return HttpResponse(200, payload.toString())
    }

    private fun handleScreenshot(): HttpResponse {
        val service = requireService() ?: return serviceUnavailable()
        val b64 = captureHandler.capture(service)
            ?: return HttpResponse(500, errorJson("screenshot_failed"))
        return HttpResponse(200, successJson(b64))
    }

    private fun handleTree(params: Map<String, String>): HttpResponse {
        val limits = try { TreeCollectionLimits.fromParams(params) }
        catch (e: IllegalArgumentException) { return badRequest(e.message ?: "invalid_collection_budget") }
        val service = requireService() ?: return serviceUnavailable()
        val activeRoot = getRootWithTimeout(service) ?: return rootWindowTimeout()
        val activeWindowId = activeRoot.windowId
        val budget = TreeCollectionBudget(limits)
        val filter = params["filter"]?.lowercase() == "true"
        val activeTree = treeHandler.buildTree(activeRoot, filter, budget)
            ?: return HttpResponse(500, errorJson("tree_build_failed"))

        // Merge in any same-task secondary windows (PopupWindow-style
        // overlays that aren't the active window root). LINE's chat
        // long-press action menu, Spinner dropdowns, ListPopupWindow,
        // and many AlertDialogs render this way and would otherwise be
        // invisible to `rootInActiveWindow`. Detection is task-based,
        // not type-based — see `collectSecondaryAppWindowTrees` for the
        // filter rationale.
        val display = computeDisplay(service)
        val displayBounds = Rect(0, 0, display.optInt("width"), display.optInt("height"))
        val secondaries = collectSecondaryAppWindowTrees(service, activeWindowId, filter, budget)

        val resultTree = if (secondaries.isEmpty()) {
            activeTree
        } else {
            buildMultiWindowRoot(activeTree, secondaries, displayBounds)
        }

        // Inline-JSON envelope: `result` is the JSON tree object, not a
        // JSON-encoded string of it. `display` is the **device** screen
        // bounds in pixels (NOT the active-window's `boundsInScreen`),
        // so the client can correctly distinguish a fullscreen activity
        // from a floating popup / dialog whose root window covers only
        // part of the device.
        val payload = JSONObject().apply {
            put("status", "success")
            put("result", resultTree.toJson())
            put("display", display)
            put("collection", JSONObject().apply {
                put("max_nodes", limits.maxNodes)
                put("max_depth", limits.maxDepth)
                put("max_children", limits.maxChildren)
                put("timeout_ms", limits.timeoutMs)
                put("visited_nodes", budget.visitedNodes)
                put("elapsed_ms", budget.elapsedMs)
                put("truncated", budget.truncated)
                put("reasons", JSONArray(budget.reasons.toList()))
            })
        }
        return HttpResponse(200, payload.toString())
    }

    /**
     * Builds an ElementNode tree for each user-facing secondary window
     * whose parent chain reaches the active window — i.e. windows the
     * active activity owns. Empty list when there's no popup/dialog
     * active (the common case) so the wire shape stays byte-identical
     * to single-window mode.
     *
     * Discrimination is parent-based, not type-based:
     * `AccessibilityWindowInfo.getType()` collapses every WindowManager
     * type that has an ActivityRecord into `TYPE_APPLICATION`, so a
     * raw type filter would either be too loose (catches every app
     * window in multi-window mode) or too narrow (misses real popups).
     * `getParent()` is the framework's own answer to "what owns this
     * window?" — for PopupWindow / PopupMenu / ListPopupWindow /
     * Spinner dropdown / anchored Dialog, the parent is the activity
     * that hosted them. (`getTaskId()` would be the tidier read but
     * is a `@hide` API not exposed by the public SDK jar.)
     *
     * In practice this is almost always PopupWindow-style overlays —
     * LINE/Slack message action menus, Spinner dropdowns, PopupMenu/
     * ListPopupWindow, anchored AlertDialogs that haven't taken focus.
     * The filter is intentionally permissive about *what* the window
     * is (custom WindowManager.addView panels, transient panels) as
     * long as the active activity is its ancestor; merge them all.
     */
    private fun collectSecondaryAppWindowTrees(
        service: AccessibilityService,
        activeWindowId: Int,
        filter: Boolean,
        budget: TreeCollectionBudget,
    ): List<ElementNode> {
        if (!budget.available()) return emptyList()
        val windows = service.windows ?: return emptyList()
        try {
            val selected = mutableListOf<AccessibilityWindowInfo>()
            val limit = (budget.limits.maxChildren - 1).coerceAtLeast(0)
            for ((index, window) in windows.withIndex()) {
                if (!budget.available()) break
                if (index >= budget.limits.maxChildren) { budget.reasons.add("max_children"); break }
                if (window.id != activeWindowId && isDescendantOf(window, activeWindowId, budget)) {
                    if (selected.size >= limit) { budget.reasons.add("max_children"); break }
                    selected.add(window)
                }
            }
            if (selected.isEmpty()) return emptyList()
            // Reserve the synthetic root before collecting secondary nodes.
            if (!budget.enter()) return emptyList()
            return selected.sortedBy { it.layer }.mapNotNull { window ->
                if (!budget.available()) return@mapNotNull null
                val root = window.root ?: return@mapNotNull null
                treeHandler.buildTree(root, filter, budget)
            }
        } finally { recycleWindows(windows) }
    }

    /**
     * Walks `window`'s parent chain (transitively) and returns true if
     * any ancestor's window id matches `ancestorId`. Caller still owns
     * `window`; we own and recycle every `getParent()` we open. Bounded
     * by `MAX_PARENT_DEPTH` so a pathological cycle (unlikely but not
     * impossible if the framework hands us back a stale info) can't
     * spin forever.
     */
    @Suppress("DEPRECATION")
    private fun isDescendantOf(window: AccessibilityWindowInfo, ancestorId: Int, budget: TreeCollectionBudget): Boolean {
        var cur: AccessibilityWindowInfo? = window.parent
        var depth = 0
        while (cur != null && depth < MAX_PARENT_DEPTH && budget.available()) {
            val parentId = cur.id
            if (parentId == ancestorId) {
                try { cur.recycle() } catch (_: Exception) {}
                return true
            }
            val next = cur.parent
            try { cur.recycle() } catch (_: Exception) {}
            cur = next
            depth++
        }
        // Defensive close of the last fetched parent we never read.
        if (cur != null) {
            try { cur.recycle() } catch (_: Exception) {}
        }
        return false
    }

    private fun recycleWindows(windows: List<AccessibilityWindowInfo>) {
        @Suppress("DEPRECATION")
        windows.forEach {
            try { it.recycle() } catch (_: Exception) {}
        }
    }

    /**
     * Wraps the active-window tree and one-or-more secondary trees under
     * a synthetic root marked with `MULTI_WINDOW_MARKER`. The wrapper
     * carries the full display bounds so downstream renderers can
     * correctly compute the screen frame for popup entries (their own
     * window bounds describe the popup only, not the device).
     *
     * The synthetic root is identifiable by class name + resource id
     * (both equal to `MULTI_WINDOW_MARKER`); client-side outline
     * renderers detect this marker and split per-window before
     * rendering. Existing protocol-version-1 clients would render the
     * synthetic root as a regular ElementNode — uglier outline but no
     * crash. We still bump `PROTOCOL_VERSION` so clients can fail fast
     * instead of producing degraded output.
     */
    private fun buildMultiWindowRoot(
        active: ElementNode,
        secondaries: List<ElementNode>,
        displayBounds: Rect,
    ): ElementNode {
        val children = mutableListOf(active)
        children.addAll(secondaries)
        return ElementNode(
            resourceId = MULTI_WINDOW_MARKER,
            uniqueId = null,
            packageName = active.packageName,
            className = MULTI_WINDOW_MARKER,
            text = "",
            contentDescription = "",
            hintText = null,
            stateDescription = null,
            boundsInScreen = displayBounds,
            clickable = false,
            longClickable = false,
            scrollable = false,
            focusable = false,
            focused = false,
            enabled = true,
            checkable = false,
            checked = false,
            selected = false,
            password = false,
            visibleToUser = true,
            collectionInfo = null,
            collectionItemInfo = null,
            children = children,
        )
    }

    private fun computeDisplay(service: AccessibilityService): JSONObject {
        // currentWindowMetrics.bounds reports the real display bounds in
        // pixels including system bars — exactly the "device screen size"
        // we want. Requires API 30+, which our minSdk already pins.
        val wm = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val bounds = wm.currentWindowMetrics.bounds
        return JSONObject().apply {
            put("width", bounds.width())
            put("height", bounds.height())
        }
    }

    private fun handleTap(params: Map<String, String>): HttpResponse {
        val service = requireService() ?: return serviceUnavailable()
        val x = params["x"]?.toFloatOrNull() ?: return badRequest("missing_x")
        val y = params["y"]?.toFloatOrNull() ?: return badRequest("missing_y")
        val ok = gestureHandler.tap(service, x, y)
        return if (ok) HttpResponse(200, successJson()) else HttpResponse(500, errorJson("tap_failed"))
    }

    private fun handleSwipe(params: Map<String, String>): HttpResponse {
        val service = requireService() ?: return serviceUnavailable()
        val startX = params["startX"]?.toFloatOrNull() ?: return badRequest("missing_startX")
        val startY = params["startY"]?.toFloatOrNull() ?: return badRequest("missing_startY")
        val endX = params["endX"]?.toFloatOrNull() ?: return badRequest("missing_endX")
        val endY = params["endY"]?.toFloatOrNull() ?: return badRequest("missing_endY")
        val duration = params["duration"]?.toLongOrNull() ?: DEFAULT_SWIPE_DURATION
        val ok = gestureHandler.swipe(service, startX, startY, endX, endY, duration)
        return if (ok) HttpResponse(200, successJson()) else HttpResponse(500, errorJson("swipe_failed"))
    }

    private fun handleGesture(params: Map<String, String>): HttpResponse {
        val service = requireService() ?: return serviceUnavailable()
        val strokesJson = params["strokes"] ?: return badRequest("missing_strokes")
        val strokes = parseStrokes(strokesJson)
        if (strokes.isEmpty()) return badRequest("invalid_strokes")
        val ok = gestureHandler.gesture(service, strokes)
        return if (ok) HttpResponse(200, successJson()) else HttpResponse(500, errorJson("gesture_failed"))
    }

    private fun handleInput(params: Map<String, String>): HttpResponse {
        val service = requireService() ?: return serviceUnavailable()
        val b64 = params["base64_text"] ?: return badRequest("missing_base64_text")
        val clear = params["clear"]?.lowercase() != "false"
        val text = try {
            String(Base64.decode(b64, Base64.DEFAULT), Charsets.UTF_8)
        } catch (e: IllegalArgumentException) {
            return badRequest("invalid_base64")
        }
        val root = getRootWithTimeout(service) ?: return rootWindowTimeout()
        val ok = inputHandler.inputText(root, text, clear)
        return if (ok) HttpResponse(200, successJson()) else badRequest("no_focused_input")
    }

    private fun handleKey(params: Map<String, String>): HttpResponse {
        val service = requireService() ?: return serviceUnavailable()
        val keyCode = params["key_code"]?.toIntOrNull() ?: return badRequest("missing_key_code")
        return when (inputHandler.keyEvent(service, keyCode)) {
            InputHandler.KeyResult.Performed -> HttpResponse(200, successJson())
            InputHandler.KeyResult.Failed -> HttpResponse(500, errorJson("key_failed"))
            InputHandler.KeyResult.Unsupported -> HttpResponse(
                400,
                errorJson(
                    code = "unsupported_keycode",
                    message = "keycode $keyCode is not supported. Allowed: HOME(3), BACK(4), RECENTS(187). Use /keyboard/input for text.",
                ),
            )
        }
    }

    private fun handleKeyboardState(): HttpResponse {
        val service = requireService() ?: return serviceUnavailable()
        val state = keyboardStateHandler.query(service)
        val payload = JSONObject().apply {
            put("visible", state.visible)
            if (state.imePackage != null) put("ime_package", state.imePackage)
        }
        return HttpResponse(200, successJson(payload))
    }

    private fun handlePaste(params: Map<String, String>): HttpResponse {
        val service = requireService() ?: return serviceUnavailable()
        val b64 = params["base64_text"] ?: return badRequest("missing_base64_text")
        val replace = params["replace"]?.lowercase() == "true"
        val text = try {
            String(Base64.decode(b64, Base64.DEFAULT), Charsets.UTF_8)
        } catch (e: IllegalArgumentException) {
            return badRequest("invalid_base64")
        }
        val root = getRootWithTimeout(service) ?: return rootWindowTimeout()
        // The PasteHandler only recycles the *focused* child it
        // finds — the root we just borrowed is on us to recycle.
        // Without this try/finally the root would leak on every
        // paste call (one AccessibilityNodeInfo per call, holding a
        // Binder reference into system_server until the next GC).
        return try {
            when (pasteHandler.paste(service, root, text, replace)) {
                PasteHandler.Result.Ok -> HttpResponse(200, successJson())
                PasteHandler.Result.NoFocusedInput -> badRequest("no_focused_input")
                PasteHandler.Result.PasteUnsupported -> HttpResponse(500, errorJson("paste_unsupported", "Focused field does not support ACTION_PASTE"))
                PasteHandler.Result.ClipboardWriteFailed -> HttpResponse(500, errorJson("clipboard_write_failed", "ClipboardManager.setPrimaryClip was denied"))
            }
        } finally {
            @Suppress("DEPRECATION")
            try { root.recycle() } catch (_: Exception) {}
        }
    }

    // ── Auth ─────────────────────────────────────────────────────

    private fun isAuthorized(headers: Map<String, String>): Boolean {
        val header = headers["authorization"] ?: return false
        if (!header.startsWith("Bearer ")) return false
        val token = header.removePrefix("Bearer ").trim()
        // Constant-time comparison so a timing oracle can't iteratively
        // recover the token via response-latency side channel. The
        // HTTP server is bound to 127.0.0.1 (see HttpServer.start)
        // and the ContentProvider is gated to adb shell, so the
        // attacker model is "local app on the device that already
        // got past the ContentProvider gate". Defence-in-depth: even
        // in that scenario, `String.equals` would short-circuit on
        // the first byte-mismatch, leaking a few hundred-ns of
        // information per try. `MessageDigest.isEqual` compares all
        // bytes in fixed time.
        val expected = authManager.getOrCreateToken()
        val a = token.toByteArray(Charsets.UTF_8)
        val b = expected.toByteArray(Charsets.UTF_8)
        return java.security.MessageDigest.isEqual(a, b)
    }

    // ── rootInActiveWindow with timeout + semaphore (csat lesson) ─

    private fun getRootWithTimeout(service: AccessibilityService): AccessibilityNodeInfo? {
        val callNum = totalRootCalls.incrementAndGet()
        if (!rootWindowSemaphore.tryAcquire(rootWindowWaitMillis, TimeUnit.MILLISECONDS)) {
            Log.w(TAG, "rootInActiveWindow #$callNum skipped: another call is still executing")
            return null
        }
        activeRootCalls.incrementAndGet()
        val lock = Any()
        var abandoned = false
        var returnedRoot: AccessibilityNodeInfo? = null
        val future = try {
            rootWindowExecutor.submit {
                try {
                    val root = service.rootInActiveWindow ?: pickFallbackRoot(service)
                    synchronized(lock) {
                        if (abandoned) recycleNode(root) else returnedRoot = root
                    }
                } finally {
                    activeRootCalls.decrementAndGet()
                    rootWindowSemaphore.release()
                }
            }
        } catch (e: Exception) {
            activeRootCalls.decrementAndGet()
            rootWindowSemaphore.release()
            throw e
        }
        return try {
            future.get(rootWindowTimeoutMillis, TimeUnit.MILLISECONDS)
            synchronized(lock) { returnedRoot.also { returnedRoot = null } }
        } catch (e: Exception) {
            synchronized(lock) {
                abandoned = true
                recycleNode(returnedRoot)
                returnedRoot = null
            }
            // A Binder call is not hard-cancellable. Retain admission until it actually finishes;
            // never dispatch a replacement while the original root query may still be running.
            if (e is TimeoutException) timeoutCount.incrementAndGet()
            Log.w(TAG, "rootInActiveWindow #$callNum unavailable: ${e.message}")
            null
        }
    }

    @Suppress("DEPRECATION")
    private fun recycleNode(node: AccessibilityNodeInfo?) {
        try { node?.recycle() } catch (_: Exception) {}
    }

    /**
     * Walk `service.windows` and return the root of the
     * highest-`layer` user-facing window (TYPE_APPLICATION or
     * TYPE_SYSTEM). Mirrors droidrun-portal's `pickFallbackRoot`.
     *
     * Caller takes ownership of the returned `AccessibilityNodeInfo`
     * and must recycle it (consistent with `rootInActiveWindow`).
     * Every `AccessibilityWindowInfo` we touch is recycled before
     * returning so we don't leak window handles.
     */
    private fun pickFallbackRoot(service: AccessibilityService): AccessibilityNodeInfo? {
        val windows = service.windows ?: return null
        return try {
            windows.asSequence()
                .filter { isUserFacingWindow(it) }
                .sortedByDescending { it.layer }
                .mapNotNull { it.root }
                .firstOrNull()
        } finally {
            @Suppress("DEPRECATION")
            windows.forEach {
                try {
                    it.recycle()
                } catch (_: Exception) {
                    // recycle() is a no-op on newer API levels and may throw
                    // if already released. Both outcomes are benign.
                }
            }
        }
    }

    private fun isUserFacingWindow(window: AccessibilityWindowInfo): Boolean =
        window.type == AccessibilityWindowInfo.TYPE_APPLICATION ||
            window.type == AccessibilityWindowInfo.TYPE_SYSTEM

    /**
     * Shut down the cached-thread pool that drives the
     * `rootInActiveWindow` timeout dance. Called from
     * `TritonKitAccessibilityService.onUnbind` so the service-stop
     * path doesn't leave a forest of "AwaitedTreeWorker" threads
     * lingering against a dead AccessibilityService.
     */
    fun close() {
        rootWindowExecutor.shutdown()
        try {
            if (!rootWindowExecutor.awaitTermination(2, TimeUnit.SECONDS)) {
                rootWindowExecutor.shutdownNow()
            }
        } catch (_: InterruptedException) {
            rootWindowExecutor.shutdownNow()
            Thread.currentThread().interrupt()
        }
    }

    private fun rootWindowTimeout() =
        HttpResponse(504, errorJson("root_window_timeout"))

    private fun requireService(): AccessibilityService? {
        val service = serviceProvider()
        if (service == null) Log.w(TAG, "requireService() returned null — AccessibilityService instance is gone")
        return service
    }

    private fun serviceUnavailable() =
        HttpResponse(503, errorJson("accessibility_service_not_running"))

    private fun badRequest(code: String, message: String? = null) =
        HttpResponse(400, errorJson(code, message))

    private fun parseStrokes(json: String): List<GestureHandler.StrokeParams> {
        return try {
            val arr = JSONArray(json)
            (0 until arr.length()).map { i ->
                val obj = arr.getJSONObject(i)
                // Optional `path` field carries multi-segment polylines
                // for arc-shaped strokes (rotate gestures). Older
                // payloads without the field fall back to the linear
                // start/end chord, which is what the bridge has always
                // done.
                val waypoints: List<GestureHandler.Point>? =
                    if (obj.has("path")) {
                        val pathArr = obj.getJSONArray("path")
                        val pts = mutableListOf<GestureHandler.Point>()
                        for (j in 0 until pathArr.length()) {
                            val p = pathArr.getJSONObject(j)
                            pts.add(
                                GestureHandler.Point(
                                    x = p.getDouble("x").toFloat(),
                                    y = p.getDouble("y").toFloat(),
                                )
                            )
                        }
                        pts
                    } else {
                        null
                    }
                GestureHandler.StrokeParams(
                    startX = obj.getDouble("startX").toFloat(),
                    startY = obj.getDouble("startY").toFloat(),
                    endX = obj.getDouble("endX").toFloat(),
                    endY = obj.getDouble("endY").toFloat(),
                    startTime = obj.getLong("startTime"),
                    duration = obj.getLong("duration"),
                    path = waypoints,
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    companion object {
        private const val TAG = "TritonKitRouter"
        private const val DEFAULT_SWIPE_DURATION = 300L
        private const val ROOT_WINDOW_TIMEOUT_SECONDS = 5L
        private const val ROOT_WINDOW_WAIT_SECONDS = 2L

        /**
         * Class name + resource id stamped on the synthetic root that
         * wraps multiple ElementNode trees when an app has secondary
         * windows visible (PopupWindow / dialog / dropdown). Reserved
         * sentinel — no real Android class or resource will ever collide
         * because '__' is not legal in Kotlin class names and Android
         * resource ids must contain a '/'.
         */
        const val MULTI_WINDOW_MARKER = "__tritonkit:multi_window__"

        /** Safety bound on the secondary-window parent walk. */
        private const val MAX_PARENT_DEPTH = 8

        /** `{status: success}` or `{status: success, result: <inline JSON>}`. */
        fun successJson(result: Any? = null): String =
            JSONObject().apply {
                put("status", "success")
                if (result != null) put("result", result)
            }.toString()

        /** `{status: error, code: <code>, error?: <message>}`. */
        fun errorJson(code: String, message: String? = null): String =
            JSONObject().apply {
                put("status", "error")
                put("code", code)
                if (message != null) put("error", message)
            }.toString()
    }
}