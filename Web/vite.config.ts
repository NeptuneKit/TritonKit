import { defineConfig, type Plugin } from "vite";
import { createViteDebugInspectorPlugin } from "@linhey/react-debug-inspector";
import react from "@vitejs/plugin-react";
// @ts-expect-error Local dev middleware is a Node ESM helper outside the TS app bundle.
import { createIosSimulatorBridgeMiddleware } from "./dev/ios-bridge/index.mjs";

function iosSimulatorBridge(): Plugin {
  return {
    name: "tritonkit-ios-simulator-bridge",
    configureServer(server) {
      server.middlewares.use(createIosSimulatorBridgeMiddleware());
    },
  };
}

export default defineConfig(({ mode }) => {
  const isDevelopment = mode === "development";

  return {
    plugins: [
      ...(isDevelopment ? [createViteDebugInspectorPlugin() as unknown as Plugin] : []),
      react(),
      iosSimulatorBridge(),
    ],
    server: {
      host: "127.0.0.1",
      port: 34127,
      strictPort: true,
    },
    preview: {
      host: "127.0.0.1",
      port: 34128,
      strictPort: true,
    },
  };
});
