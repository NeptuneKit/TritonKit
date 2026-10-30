import { useCallback, useEffect, useState } from "react";
import { ThemeProvider } from "@linhey/rhine-design/theme";
import { WorkspaceShell } from "./components/WorkspaceShell";
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
      <ThemeProvider defaultTheme="arknights">
        <WorkspaceShell>
          <NodeRenderer
            node={root}
            onSplit={handleSplit}
            onClose={handleClose}
            onUnload={handleUnload}
            onSelectCard={handleSelectCard}
            onDividerDrag={handleDividerDrag}
            isRoot={true}
          />
        </WorkspaceShell>
      </ThemeProvider>
    </AppContextProvider>
  );
}

export default App;
