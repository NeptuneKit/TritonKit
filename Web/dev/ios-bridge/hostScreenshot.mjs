import { randomUUID } from "node:crypto";
import { mkdir, readFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { runTritonJSON } from "./process.mjs";
import { imageMimeType, readImageDimensions } from "./image.mjs";
import { isIOSRuntimeMirror, resolveIOSRuntimeMirrorTarget } from "./runtimeMirror.mjs";

export async function captureHostScreenshot(tritonPath, platform, target, options = {}) {
  const outputDir = join(tmpdir(), `tritonkit-web-host-${randomUUID()}`);
  const runtimeMirror = isIOSRuntimeMirror(platform, options);
  const outputPath = join(outputDir, runtimeMirror ? "screenshot.png" : "screenshot.bin");
  await mkdir(outputDir, { recursive: true });
  try {
    const runtimeTarget = runtimeMirror ? await resolveIOSRuntimeMirrorTarget(tritonPath, target, options) : null;
    const args = runtimeMirror
      ? ["screenshot", "--target", runtimeTarget, "--output", outputPath, "--json"]
      : platform === "ios"
        ? ["sim", "screenshot", "--simulator", target, "--output", outputPath, "--json"]
        : ["device", "screenshot", "--platform", platform, "--device", target, "--output", outputPath, "--json"];
    const payload = await runTritonJSON(tritonPath, args);
    const image = await readFile(outputPath);
    const dimensions = readImageDimensions(image);
    const mimeType = imageMimeType(image);
    return {
      ok: true,
      simulator: target,
      source: {
        command: `triton ${args.join(" ")}`,
        runtimeScope: runtimeMirror ? "app-runtime" : platform === "ios" ? "host-simulator" : `host-${platform}`,
        readonly: true,
      },
      artifact: payload.artifact,
      pixelWidth: payload.pixelWidth ?? dimensions.width,
      pixelHeight: payload.pixelHeight ?? dimensions.height,
      dataUrl: `data:${mimeType};base64,${image.toString("base64")}`,
    };
  } finally {
    await rm(outputDir, { recursive: true, force: true });
  }
}

