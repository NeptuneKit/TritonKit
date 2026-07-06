import { spawn } from "node:child_process";

export const defaultHostInputBaseURL = "http://127.0.0.1:19421";
export const defaultManagedTritonServeHost = process.env.TRITONKIT_WEB_MANAGED_SERVE_HOST || "0.0.0.0";
export const defaultRuntimeDataBaseURL = "http://127.0.0.1:19421";

let managedTritonServeProcess;

export function getManagedTritonServeBindHost() {
  return defaultManagedTritonServeHost;
}

export async function ensureTritonServe(tritonPath, baseURL) {
  if (await canReachTritonServe(baseURL)) return;
  if (!managedTritonServeProcess || managedTritonServeProcess.exitCode !== null) {
    const url = new URL(baseURL);
    managedTritonServeProcess = spawn(tritonPath, [
      "serve",
      "--host",
      defaultManagedTritonServeHost,
      "--port",
      String(url.port || 19421),
    ], {
      stdio: "ignore",
    });
    managedTritonServeProcess.once("error", () => {});
  }

  const deadline = Date.now() + 3000;
  while (Date.now() < deadline) {
    if (await canReachTritonServe(baseURL)) return;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`triton serve did not become ready at ${baseURL}`);
}

export async function describeFetchBridgeError(response, fallback) {
  try {
    const payload = await response.json();
    const error = payload?.error;
    const parts = [error?.code, error?.message, error?.hint].filter(Boolean);
    if (parts.length > 0) return parts.join(" · ");
  } catch {
    // Fall back to the HTTP status below.
  }
  return `${fallback}: ${response.status}`;
}

async function canReachTritonServe(baseURL) {
  try {
    const response = await fetch(new URL("/health", baseURL), { signal: AbortSignal.timeout(500) });
    return response.ok;
  } catch {
    return false;
  }
}

