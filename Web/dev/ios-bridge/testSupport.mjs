import { chmod, mkdtemp, writeFile } from "node:fs/promises";
import { createServer as createTestHttpServer } from "node:http";
import { join } from "node:path";
import { tmpdir } from "node:os";

export function invokeMiddleware(middleware, request) {
  return new Promise((resolveResponse, reject) => {
    const response = {
      statusCode: 200,
      headers: {},
      setHeader(name, value) {
        this.headers[name.toLowerCase()] = value;
      },
      end(body) {
        resolveResponse({
          statusCode: this.statusCode,
          headers: this.headers,
          body: String(body ?? ""),
        });
      },
    };

    Promise.resolve(
      middleware(
        {
          method: request.method,
          url: request.url,
          on(event, callback) {
            if (event === "data" && request.body) {
              callback(Buffer.from(request.body));
            }
            if (event === "end") {
              queueMicrotask(callback);
            }
            return this;
          },
        },
        response,
        () => reject(new Error("readonly host input route should not call next()"))
      )
    ).catch(reject);
  });
}

export function createFakeHostInputServer(received, responseBody) {
  return new Promise((resolve, reject) => {
    const server = createTestHttpServer((req, res) => {
      const url = new URL(req.url ?? "/", "http://127.0.0.1");
      let body = "";
      req.on("data", (chunk) => {
        body += chunk;
      });
      req.on("end", () => {
        received.push({
          method: req.method,
          pathname: url.pathname,
          target: url.searchParams.get("target"),
          body: JSON.parse(body || "{}"),
        });
        res.statusCode = 200;
        res.setHeader("content-type", "application/json");
        res.end(JSON.stringify(responseBody));
      });
    });
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      resolve({
        baseURL: `http://127.0.0.1:${address.port}`,
        close: () => new Promise((resolveClose, rejectClose) => server.close((error) => error ? rejectClose(error) : resolveClose())),
      });
    });
  });
}

export function createFakeRuntimeDataServer(refs) {
  return new Promise((resolve, reject) => {
    const server = createTestHttpServer((req, res) => {
      const url = new URL(req.url ?? "/", "http://127.0.0.1");
      const ref = decodeURIComponent(url.pathname.replace(/^\/data\//, ""));
      const data = refs[ref];
      if (!data) {
        res.statusCode = 404;
        res.end();
        return;
      }
      res.statusCode = 200;
      res.setHeader("content-type", "image/png");
      res.end(data);
    });
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      resolve({
        baseURL: `http://127.0.0.1:${address.port}`,
        close: () => new Promise((resolveClose, rejectClose) => server.close((error) => error ? rejectClose(error) : resolveClose())),
      });
    });
  });
}

export async function createFakeTritonScript({ stdout, outputTemplate }) {
  const directory = await mkdtemp(join(tmpdir(), "tritonkit-web-bridge-test-"));
  const scriptPath = join(directory, "fake-triton.mjs");
  const script = `#!/usr/bin/env node
import { writeFileSync } from "node:fs";

const artifactIndex = process.argv.indexOf("--output");
if (artifactIndex >= 0) {
  const outputPath = process.argv[artifactIndex + 1];
  if (outputPath) {
    writeFileSync(outputPath, Buffer.from(${JSON.stringify(Buffer.from(outputTemplate).toString("base64"))}, "base64"));
  }
}

const payload = JSON.parse(${JSON.stringify(stdout)});
if (artifactIndex >= 0) {
  payload.artifact = process.argv[artifactIndex + 1];
}
process.stdout.write(JSON.stringify(payload));
`;
  await writeFile(scriptPath, script, "utf8");
  await chmod(scriptPath, 0o755);
  return scriptPath;
}

export async function createFakeTritonScriptFromSource(script) {
  const directory = await mkdtemp(join(tmpdir(), "tritonkit-web-bridge-test-"));
  const scriptPath = join(directory, "fake-triton.mjs");
  await writeFile(scriptPath, script, "utf8");
  await chmod(scriptPath, 0o755);
  return scriptPath;
}

export function pngBytes(width, height) {
  const buffer = Buffer.alloc(24);
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(buffer, 0);
  buffer.writeUInt32BE(width, 16);
  buffer.writeUInt32BE(height, 20);
  return buffer;
}
