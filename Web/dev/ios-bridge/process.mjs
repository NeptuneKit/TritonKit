import { existsSync } from "node:fs";
import { join } from "node:path";
import { spawn } from "node:child_process";

export function resolveTritonBinary(root) {
  const candidates = [
    process.env.TRITONKIT_TRITON_BIN,
    join(root, "CLI", ".build", "debug", "triton"),
    join(root, "CLI", ".build", "arm64-apple-macosx", "debug", "triton"),
  ].filter(Boolean);

  const found = candidates.find((candidate) => existsSync(candidate));
  if (!found) {
    throw new Error("No triton binary found. Run `swift build --package-path CLI --product triton` first.");
  }
  return found;
}

export async function runTritonJSON(tritonPath, args) {
  const result = await runCommand(tritonPath, args);
  if (result.exitCode !== 0 || result.signal) {
    throw new Error(result.stderr || result.stdout || `triton exited with code ${result.exitCode} signal ${result.signal}`);
  }
  try {
    return JSON.parse(result.stdout);
  } catch (error) {
    throw new Error(`Failed to parse triton JSON: ${error instanceof Error ? error.message : String(error)}`);
  }
}

export async function runTritonCapture(tritonPath, args, platform) {
  const result = await runCommand(tritonPath, args);
  return {
    id: `${platform}-${Date.now()}-${Math.random().toString(16).slice(2)}`,
    platform,
    command: `triton ${args.join(" ")}`,
    ok: result.exitCode === 0,
    exitCode: result.exitCode,
    stdout: result.stdout,
    stderr: result.stderr,
    parsed: result.exitCode === 0 ? tryParseJSON(result.stdout) : null,
  };
}

export function tryParseJSON(value) {
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

export function runCommand(command, args, options = {}) {
  return new Promise((resolveCommand, reject) => {
    const child = spawn(command, args, { stdio: [options.stdin === undefined ? "ignore" : "pipe", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => {
      child.kill("SIGTERM");
      reject(new Error(`Timed out running ${command} ${args.join(" ")}`));
    }, 20_000);

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString("utf8");
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString("utf8");
    });
    if (options.stdin !== undefined) {
      child.stdin.end(options.stdin);
    }
    child.on("error", (error) => {
      clearTimeout(timer);
      reject(error);
    });
    child.on("close", (exitCode, signal) => {
      clearTimeout(timer);
      resolveCommand({ exitCode: exitCode ?? 1, signal: signal ?? null, stdout, stderr });
    });
  });
}
