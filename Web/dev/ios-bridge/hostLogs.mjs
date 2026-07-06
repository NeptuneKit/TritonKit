import { randomUUID } from "node:crypto";
import { mkdir, readFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { runTritonJSON, tryParseJSON } from "./process.mjs";

export async function captureHostLogs(tritonPath, target) {
  const outputDir = join(tmpdir(), `tritonkit-web-logs-${randomUUID()}`);
  const outputPath = join(outputDir, "host-logs.ndjson");
  await mkdir(outputDir, { recursive: true });
  try {
    const args = ["sim", "logs", "--simulator", target, "--output", outputPath, "--duration", "2", "--style", "ndjson", "--json"];
    await runTritonJSON(tritonPath, args);
    const raw = await readFile(outputPath, "utf8");
    const entries = parseHostLogEntries(raw);
    const capturedAt = resolveLogsCapturedAt(raw) ?? new Date().toISOString();
    return {
      ok: true,
      capturedAt,
      source: {
        command: redactArtifactPath(`triton ${args.join(" ")}`, outputPath),
        runtimeScope: "host-simulator",
        readonly: true,
      },
      entries,
    };
  } finally {
    await rm(outputDir, { recursive: true, force: true });
  }
}

export function parseHostLogEntries(raw) {
  return raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line, index) => {
      const parsed = tryParseJSON(line);
      const timestamp = normalizeLogTimestamp(parsed) ?? null;
      return {
        id: `host-log-${index}`,
        time: formatLogTime(timestamp),
        level: normalizeLogLevel(parsed),
        message: normalizeLogMessage(parsed, line),
      };
    });
}

export function resolveLogsCapturedAt(raw) {
  const lines = raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  const last = lines.at(-1);
  const parsed = last ? tryParseJSON(last) : null;
  return normalizeLogTimestamp(parsed);
}

function redactArtifactPath(command, outputPath) {
  return command.replace(outputPath, "<tmp.ndjson>");
}

function normalizeLogTimestamp(record) {
  if (!record || typeof record !== "object") return null;
  const candidates = [
    record.timestamp,
    record.date,
    record.time,
  ];
  for (const candidate of candidates) {
    if (typeof candidate === "string" && !Number.isNaN(Date.parse(candidate))) {
      return new Date(candidate).toISOString();
    }
  }
  return null;
}

function formatLogTime(isoTimestamp) {
  if (!isoTimestamp) return "--:--:--";
  return new Date(isoTimestamp).toLocaleTimeString("en-GB", { hour12: false, timeZone: "UTC" });
}

function normalizeLogLevel(record) {
  if (!record || typeof record !== "object") return "info";
  const value = [
    record.messageType,
    record.level,
    record.severity,
  ].find((candidate) => typeof candidate === "string");
  const normalized = String(value ?? "info").toLowerCase();
  if (normalized.includes("error") || normalized.includes("fault")) return "error";
  if (normalized.includes("warn")) return "warn";
  return "info";
}

function normalizeLogMessage(record, fallbackLine) {
  if (record && typeof record === "object") {
    const message = [
      record.eventMessage,
      record.message,
      record.msg,
    ].find((candidate) => typeof candidate === "string" && candidate.trim().length > 0);
    if (message) return message.trim();
  }
  return fallbackLine;
}
