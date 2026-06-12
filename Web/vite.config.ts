import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";
// @ts-expect-error Local dev middleware is a Node ESM helper outside the TS app bundle.
import { createIosSimulatorBridgeMiddleware } from "./dev/iosSimulatorBridge.mjs";

function iosSimulatorBridge(): Plugin {
  return {
    name: "tritonkit-ios-simulator-bridge",
    configureServer(server) {
      server.middlewares.use(createIosSimulatorBridgeMiddleware());
    },
  };
}

export default defineConfig({
  plugins: [react(), iosSimulatorBridge()],
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
});
