import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "antd/dist/reset.css";
import App from "./App";
import "./styles.css";

const root = createRoot(document.getElementById("root") as HTMLElement);

if (import.meta.env.DEV) {
  void import("@linhey/react-debug-inspector").then(({ initInspector }) => {
    initInspector();
  });
}

root.render(
  <StrictMode>
    <App />
  </StrictMode>
);
