import { StrictMode, useState } from "react";
import { createRoot } from "react-dom/client";
import "antd/dist/reset.css";
import { App } from "./App";
import "./styles.css";

const root = createRoot(document.getElementById("root") as HTMLElement);

async function renderApp() {
  if (import.meta.env.DEV) {
    const { Inspector } = await import("react-dev-inspector");

    function DevInspectorApp() {
      const [active, setActive] = useState(false);

      return (
        <>
          <Inspector active={active} onActiveChange={setActive}>
            <App />
          </Inspector>
          <button
            aria-pressed={active}
            onClick={() => setActive(true)}
            style={{
              position: "fixed",
              right: 16,
              bottom: 16,
              zIndex: 10000001,
              border: "1px solid rgba(105, 177, 255, 0.5)",
              borderRadius: 999,
              background: active ? "#1677ff" : "rgba(22, 119, 255, 0.88)",
              color: "#fff",
              cursor: active ? "default" : "pointer",
              font: "12px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
              padding: "8px 12px",
              pointerEvents: active ? "none" : "auto",
              boxShadow: "0 8px 24px rgba(0, 0, 0, 0.28)",
            }}
            title={active ? "React Inspector active; press Esc to exit" : "Open React Inspector"}
            type="button"
          >
            {active ? "Inspecting · Esc" : "React Inspector"}
          </button>
        </>
      );
    }

    root.render(
      <StrictMode>
        <DevInspectorApp />
      </StrictMode>
    );
    return;
  }

  root.render(
    <StrictMode>
      <App />
    </StrictMode>
  );
}

void renderApp();
