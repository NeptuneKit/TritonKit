export const SUPPORTED_CARD_TYPES = ["stream", "inspector", "workbench"] as const;

export type CardType = (typeof SUPPORTED_CARD_TYPES)[number];

export type LeafNode = {
  kind: "leaf";
  id: string;
  card: CardType | null;
};

export type SplitNode = {
  kind: "split";
  id: string;
  direction: "v" | "h";
  ratio: number;
  first: LayoutNode;
  second: LayoutNode;
};

export type LayoutNode = LeafNode | SplitNode;

let idCounter = 0;

function nextId() {
  return String(++idCounter);
}

function setMaxId(root: LayoutNode) {
  const parseId = (id: string) => parseInt(id, 10) || 0;
  idCounter = Math.max(idCounter, parseId(root.id));
  if (root.kind === "split") {
    setMaxId(root.first);
    setMaxId(root.second);
  }
}

function isCardType(card: unknown): card is CardType {
  return SUPPORTED_CARD_TYPES.includes(card as CardType);
}

function pruneUnsupportedCards(root: LayoutNode): LayoutNode {
  if (root.kind === "leaf") {
    return { ...root, card: isCardType(root.card) ? root.card : null };
  }
  return {
    ...root,
    first: pruneUnsupportedCards(root.first),
    second: pruneUnsupportedCards(root.second),
  };
}

export function makeInitialRoot(): LayoutNode {
  return {
    kind: "split",
    id: nextId(),
    direction: "v",
    ratio: 0.58,
    first: { kind: "leaf", id: nextId(), card: "stream" },
    second: { kind: "leaf", id: nextId(), card: "workbench" },
  };
}

export function loadInitialRoot(): LayoutNode {
  try {
    if (typeof globalThis.localStorage?.getItem !== "function") return makeInitialRoot();
    const saved = globalThis.localStorage.getItem("triton-layout");
    if (saved) {
      const parsed = JSON.parse(saved);
      if (parsed && typeof parsed === "object" && parsed.id) {
        setMaxId(parsed as LayoutNode);
        return pruneUnsupportedCards(parsed as LayoutNode);
      }
    }
  } catch (error) {
    console.error("Failed to parse saved layout", error);
  }
  return makeInitialRoot();
}

export function updateNode(root: LayoutNode, id: string, fn: (node: LayoutNode) => LayoutNode): LayoutNode {
  if (root.id === id) return fn(root);
  if (root.kind === "split") {
    return {
      ...root,
      first: updateNode(root.first, id, fn),
      second: updateNode(root.second, id, fn),
    };
  }
  return root;
}

export function removeLeaf(root: LayoutNode, id: string): LayoutNode | null {
  if (root.kind === "leaf") return root.id === id ? null : root;
  const first = removeLeaf(root.first, id);
  const second = removeLeaf(root.second, id);
  if (first === null) return second;
  if (second === null) return first;
  return { ...root, first, second };
}

export function splitLeaf(root: LayoutNode, id: string, direction: "v" | "h"): LayoutNode {
  return updateNode(root, id, (node) => {
    if (node.kind !== "leaf") return node;
    return {
      kind: "split",
      id: nextId(),
      direction,
      ratio: 0.5,
      first: node,
      second: { kind: "leaf", id: nextId(), card: null },
    };
  });
}
