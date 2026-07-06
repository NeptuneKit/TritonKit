import { useCallback, useEffect, useState } from "react";
import { ConfigProvider, theme } from "antd";
import { AppContextProvider } from "./AppContext";
import { NodeRenderer } from "./components/AppCanvas";
import {
  type CardType,
  type LayoutNode,
  loadInitialRoot,
  makeInitialRoot,
  removeLeaf,
  splitLeaf,
  updateNode,
} from "./layoutModel";
import "./styles.css";

export function App() {
  const [root, setRoot] = useState<LayoutNode>(loadInitialRoot);

  useEffect(() => {
    if (typeof globalThis.localStorage?.setItem === "function") {
      globalThis.localStorage.setItem("triton-layout", JSON.stringify(root));
    }
  }, [root]);

  const handleSplit = useCallback((id: string, direction: "v" | "h") => {
    setRoot((prev) => splitLeaf(prev, id, direction));
  }, []);

  const handleClose = useCallback((id: string) => {
    setRoot((prev) => removeLeaf(prev, id) ?? makeInitialRoot());
  }, []);

  const handleUnload = useCallback((id: string) => {
    setRoot((prev) =>
      updateNode(prev, id, (node) => {
        if (node.kind !== "leaf") return node;
        return { ...node, card: null };
      })
    );
  }, []);

  const handleSelectCard = useCallback((id: string, card: CardType) => {
    setRoot((prev) =>
      updateNode(prev, id, (node) => {
        if (node.kind !== "leaf") return node;
        return { ...node, card };
      })
    );
  }, []);

  const handleDividerDrag = useCallback((id: string, delta: number) => {
    setRoot((prev) =>
      updateNode(prev, id, (node) => {
        if (node.kind !== "split") return node;
        return { ...node, ratio: Math.min(0.9, Math.max(0.1, node.ratio + delta)) };
      })
    );
  }, []);

  return (
    <AppContextProvider layoutRoot={root}>
      <ConfigProvider
        theme={{
          algorithm: theme.darkAlgorithm,
          token: {
            colorPrimary: "#1677ff",
            colorSuccess: "#52c41a",
            colorWarning: "#faad14",
            colorError: "#ff4d4f",
            borderRadius: 8,
            fontSize: 12,
          },
        }}
      >
        <div className="triton-app">
          <header className="triton-header">
            <div className="header-brand">
              <span className="header-logo">TRITON</span>
              <div className="header-divider" />
              <span className="header-subtitle">开发者控制台</span>
            </div>
            <div className="header-meta">
              <div className="status-pill">
                <div className="status-dot" />
                服务运行中 · 127.0.0.1:19421
              </div>
            </div>
          </header>

          <div className="canvas-root">
            <NodeRenderer
              node={root}
              onSplit={handleSplit}
              onClose={handleClose}
              onUnload={handleUnload}
              onSelectCard={handleSelectCard}
              onDividerDrag={handleDividerDrag}
              isRoot={true}
            />
          </div>
        </div>
      </ConfigProvider>
    </AppContextProvider>
  );
}

export default App;
