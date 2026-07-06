import { createServer as createHttpServer } from "node:http";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { resolveTritonBinary, runTritonJSON } from "./process.mjs";
import {
  collectHostTargets,
  mapTritonDeviceListToWebTargets,
  mapTritonHostCapturesToWebTargets,
  mapTritonSimListToWebTargets,
} from "./hostTargets.mjs";
import { captureHostLogs } from "./hostLogs.mjs";
import { captureHostHierarchy } from "./hierarchy.mjs";
import { webHostRuntimeError } from "./runtimeMirror.mjs";
import { readRequestBody, sendJSON } from "./http.mjs";
import {
  defaultHostInputBaseURL,
  defaultRuntimeDataBaseURL,
  ensureTritonServe,
  getManagedTritonServeBindHost,
} from "./tritonServe.mjs";
import { captureHostScreenshot } from "./hostScreenshot.mjs";
import { dispatchHostInput } from "./hostInput.mjs";
import { handleStreamRoute } from "./streamRoutes.mjs";

export {
  getManagedTritonServeBindHost,
  mapTritonDeviceListToWebTargets,
  mapTritonHostCapturesToWebTargets,
  mapTritonSimListToWebTargets,
};

const bridgeRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");

export function createIosSimulatorBridgeMiddleware(options = {}) {
  const root = options.root ? resolve(options.root) : bridgeRoot;
  const tritonPath = options.tritonPath ? resolve(options.tritonPath) : resolveTritonBinary(root);
  const hostInputBaseURL = options.hostInputBaseURL || defaultHostInputBaseURL;
  const runtimeDataBaseURL = options.runtimeDataBaseURL || defaultRuntimeDataBaseURL;

  return async function iosSimulatorBridgeMiddleware(req, res, next) {
    if (!req.url?.startsWith("/web/")) {
      next();
      return;
    }

    try {
      const url = new URL(req.url, "http://127.0.0.1");

      if (url.pathname === "/web/ios-simulator/targets") {
        const payload = await runTritonJSON(tritonPath, ["sim", "list", "--json"]);
        sendJSON(res, 200, mapTritonSimListToWebTargets(payload));
        return;
      }

      if (url.pathname === "/web/host-targets") {
        if (url.searchParams.get("__tritonkit_mock_host_targets") === "request-failed") {
          sendJSON(res, 502, {
            ok: false,
            error: {
              code: "web_host_targets_forced_failure",
              message: "Forced /web/host-targets failure for dev browser smoke.",
            },
          });
          return;
        }
        sendJSON(res, 200, await collectHostTargets(tritonPath));
        return;
      }

      if (url.pathname === "/web/target-registry") {
        await handleTargetRegistryRoute(res, tritonPath, hostInputBaseURL);
        return;
      }

      if (url.pathname === "/web/host-logs") {
        await handleHostLogsRoute(url, res, tritonPath);
        return;
      }

      if (url.pathname === "/web/host-hierarchy") {
        await handleHostHierarchyRoute(url, req, res, tritonPath, runtimeDataBaseURL);
        return;
      }

      if (await handleStreamRoute({ url, req, res, tritonPath, hostInputBaseURL })) {
        return;
      }

      if (url.pathname === "/web/host-screenshot") {
        await handleHostScreenshotRoute(url, res, tritonPath);
        return;
      }

      if (url.pathname === "/web/host-input" && req.method === "POST") {
        await handleHostInputRoute(url, req, res, tritonPath, hostInputBaseURL, options);
        return;
      }

      if (url.pathname === "/web/host-ax") {
        await handleHostAxRoute(url, res, tritonPath);
        return;
      }

      sendJSON(res, 404, { ok: false, error: { code: "web_ios_bridge_route_not_found" } });
    } catch (error) {
      sendJSON(res, 502, {
        ok: false,
        error: {
          code: "web_ios_bridge_failed",
          message: error instanceof Error ? error.message : String(error),
          hint: "Verify `CLI/.build/debug/triton sim list --json` works, and boot a simulator before requesting screenshots.",
        },
      });
    }
  };
}

async function handleTargetRegistryRoute(res, tritonPath, hostInputBaseURL) {
  try {
    await ensureTritonServe(tritonPath, hostInputBaseURL);
    const upstream = await fetch(new URL("/web/target-registry", hostInputBaseURL));
    const payload = await upstream.json();
    sendJSON(res, upstream.status, payload);
  } catch (error) {
    sendJSON(res, 502, {
      ok: false,
      error: {
        code: "web_target_registry_unavailable",
        message: String(error?.message ?? error),
      },
    });
  }
}

async function handleHostLogsRoute(url, res, tritonPath) {
  const platform = url.searchParams.get("platform") || "ios";
  const target = url.searchParams.get("target") || "booted";
  if (platform !== "ios") {
    sendJSON(res, 501, {
      ok: false,
      error: {
        code: "web_host_logs_platform_not_supported",
        message: "Readonly host logs are currently only exposed for iOS Simulator targets.",
      },
    });
    return;
  }
  sendJSON(res, 200, await captureHostLogs(tritonPath, target));
}

async function handleHostHierarchyRoute(url, req, res, tritonPath, runtimeDataBaseURL) {
  const platform = url.searchParams.get("platform") || "ios";
  const target = url.searchParams.get("target") || "local";
  const scope = url.searchParams.get("scope") || undefined;
  const kind = url.searchParams.get("kind") || undefined;
  const source = url.searchParams.get("source") || undefined;
  if (!["GET", "POST"].includes(req.method ?? "GET")) {
    sendJSON(res, 405, {
      ok: false,
      error: {
        code: "web_host_hierarchy_method_not_allowed",
        message: "Host hierarchy capture only supports GET and POST.",
      },
    });
    return;
  }
  if (!["ios", "android", "harmony"].includes(platform)) {
    sendJSON(res, 501, {
      ok: false,
      error: {
        code: "web_host_hierarchy_platform_not_supported",
        message: `Readonly host hierarchy is not available for platform: ${platform}`,
      },
    });
    return;
  }
  try {
    const payload = await captureHostHierarchy(tritonPath, platform, target, req.method ?? "GET", {
      runtimeDataBaseURL,
      scope,
      kind,
      source,
      target,
    });
    sendJSON(res, 200, payload);
  } catch (error) {
    sendJSON(res, 409, webHostRuntimeError(platform, { scope, kind, source, target }, error, "hierarchy"));
  }
}

async function handleHostScreenshotRoute(url, res, tritonPath) {
  const platform = url.searchParams.get("platform") || "ios";
  const target = url.searchParams.get("target") || "booted";
  const scope = url.searchParams.get("scope") || "";
  const kind = url.searchParams.get("kind") || "";
  const source = url.searchParams.get("source") || "";
  try {
    const screenshot = await captureHostScreenshot(tritonPath, platform, target, { scope, kind, source, target });
    sendJSON(res, 200, screenshot);
  } catch (error) {
    sendJSON(res, 409, webHostRuntimeError(platform, { scope, kind, source, target }, error, "screenshot"));
  }
}

async function handleHostInputRoute(url, req, res, tritonPath, hostInputBaseURL, options) {
  const platform = url.searchParams.get("platform") || "ios";
  const target = url.searchParams.get("target") || "local";
  const scope = url.searchParams.get("scope") || "";
  const kind = url.searchParams.get("kind") || "";
  const source = url.searchParams.get("source") || "";
  const body = await readRequestBody(req);
  const input = JSON.parse(body || "{}");
  try {
    const result = await dispatchHostInput(tritonPath, platform, target, input, {
      scope,
      kind,
      source,
      target,
      hostInputBaseURL,
      manageHostInputServer: !options.hostInputBaseURL,
    });
    sendJSON(res, 200, result);
  } catch (error) {
    sendJSON(res, 409, webHostRuntimeError(platform, { scope, kind, source, target }, error, "input"));
  }
}

async function handleHostAxRoute(url, res, tritonPath) {
  const target = url.searchParams.get("target") || "booted";
  try {
    console.log("[BRIDGE] Using tritonPath:", tritonPath);
    console.log("[BRIDGE] Environment:", {
      PATH: process.env.PATH,
      DEVELOPER_DIR: process.env.DEVELOPER_DIR,
      TERM: process.env.TERM,
      HOME: process.env.HOME,
      USER: process.env.USER,
    });
    const payload = await runTritonJSON(tritonPath, ["sim", "ax", "--device", target, "--json"]);
    sendJSON(res, 200, { ok: true, target, tree: payload });
  } catch (error) {
    sendJSON(res, 409, {
      ok: false,
      error: {
        code: "web_host_ax_failed",
        message: error instanceof Error ? error.message : String(error),
      },
    });
  }
}

export function createStandaloneIosSimulatorBridgeServer(options = {}) {
  return createHttpServer(createIosSimulatorBridgeMiddleware(options));
}

