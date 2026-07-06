import { runCommand, tryParseJSON } from "./process.mjs";
import { isIOSRuntimeMirror, resolveIOSRuntimeMirrorTarget } from "./runtimeMirror.mjs";
import { defaultHostInputBaseURL, describeFetchBridgeError, ensureTritonServe } from "./tritonServe.mjs";

export async function dispatchHostInput(tritonPath, platform, target, input, options = {}) {
  if (isWebHostInputTarget(platform, options)) {
    return dispatchHostTargetInput(tritonPath, platform, target, input, options);
  }
  if (!isIOSRuntimeMirror(platform, options)) {
    return {
      ok: false,
      action: String(input?.type ?? "input"),
      message: "Web host input is only enabled for iOS real-device App runtime mirror targets in this bridge.",
    };
  }
  const runtimeTarget = await resolveIOSRuntimeMirrorTarget(tritonPath, target, options);
  const result = await runCommand(tritonPath, ["input", "--target", runtimeTarget, "--json", "--summary"], {
    stdin: `${JSON.stringify(input)}\n`,
  });
  if (result.exitCode !== 0) {
    throw new Error(result.stderr || result.stdout || `triton input exited with ${result.exitCode}`);
  }
  const lines = result.stdout.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
  const first = lines.map(tryParseJSON).find((record) => record && typeof record === "object" && "ok" in record);
  if (!first) {
    throw new Error("triton input did not return a JSON input result");
  }
  return first;
}

function isWebHostInputTarget(platform, options = {}) {
  if (!["ios", "android", "harmony"].includes(platform)) return false;
  if (isIOSRuntimeMirror(platform, options)) return false;
  return options.scope === "simulator" ||
    options.scope === "emulator" ||
    options.source === "host" ||
    options.kind === "simulator" ||
    options.kind === "emulator";
}

async function dispatchHostTargetInput(tritonPath, platform, target, input, options = {}) {
  if (options.manageHostInputServer) {
    await ensureTritonServe(tritonPath, options.hostInputBaseURL || defaultHostInputBaseURL);
  }
  const targetID = `host:${platform}:${target}`;
  const url = new URL("/web/input", options.hostInputBaseURL || defaultHostInputBaseURL);
  url.searchParams.set("target", targetID);
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(input),
  });
  if (!response.ok) {
    throw new Error(await describeFetchBridgeError(response, "triton serve /web/input failed"));
  }
  return response.json();
}

