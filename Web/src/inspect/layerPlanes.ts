import type { HierarchyLayerNode, HierarchyScene } from "../types";
import { resolveDefaultMaterialSource } from "../data/hierarchyMaterialPolicy";

export const INITIAL_LAYER_CAMERA = { x: 12, y: -25 };
export const MAX_LAYER_PLANES = 200;
export type LayerCamera = typeof INITIAL_LAYER_CAMERA;
const clamp = (n: number, min: number, max: number) => Math.max(min, Math.min(max, n));

export function rotateLayerCamera(camera: LayerCamera, dx: number, dy: number): LayerCamera {
  return { x: clamp(camera.x - dy, -65, 65), y: clamp(camera.y + dx, -75, 75) };
}
export function layerCameraKey(camera: LayerCamera, key: string): LayerCamera | null {
  switch (key) {
    case "ArrowLeft": return rotateLayerCamera(camera, -5, 0);
    case "ArrowRight": return rotateLayerCamera(camera, 5, 0);
    case "ArrowUp": return rotateLayerCamera(camera, 0, -5);
    case "ArrowDown": return rotateLayerCamera(camera, 0, 5);
    case "Home": return { ...INITIAL_LAYER_CAMERA };
    default: return null;
  }
}
export function dragLayerCamera(camera: LayerCamera, dx: number, dy: number, width: number, height: number) {
  return rotateLayerCamera(camera, dx / Math.max(1, width) * 140, dy / Math.max(1, height) * 140);
}
export function makeLayerPlanes(scene: HierarchyScene, selectedId?: string | null) {
  const byId = new Map(scene.nodes.map(node => [node.id, node]));
  const visible = (node: HierarchyLayerNode) => {
    let current: HierarchyLayerNode | undefined = node;
    const visited = new Set<string>();
    while (current) {
      if (visited.has(current.id)) return false;
      visited.add(current.id);
      // Zero-sized structural nodes have no plane but may contain visible descendants.
      const hasArea = current.frame.width > 0 && current.frame.height > 0;
      if ((current.visible === false && hasArea) || current.layer?.isHidden || current.view?.isHidden
        || [current.layer?.opacity, current.view?.alpha, current.style?.alpha]
          .some(alpha => alpha !== undefined && alpha <= 0)) return false;
      current = current.parentId ? byId.get(current.parentId) : undefined;
    }
    return true;
  };
  const candidates = scene.nodes.filter(node => {
    const f = node.frame;
    return visible(node) && [f.x, f.y, f.width, f.height, node.depth].every(Number.isFinite)
      && f.width > 0 && f.height > 0 && f.width <= 100_000 && f.height <= 100_000;
  });
  const selected = candidates.find(node => node.id === selectedId);
  const bounded = candidates.slice(0, MAX_LAYER_PLANES);
  if (selected && !bounded.includes(selected)) bounded[MAX_LAYER_PLANES - 1] = selected;
  const planes = bounded.map(node => ({ node, depth: clamp(node.depth, 0, 64), image: resolveDefaultMaterialSource(node)?.dataUrl }));
  return { planes, omitted: candidates.length - bounded.length, missingImages: planes.filter(plane => !plane.image).length };
}
