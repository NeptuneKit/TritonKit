import { useEffect, useId, useMemo, useRef, useState } from "react";
import { Button, EmptyState, Inline, NumberField, Stack, Text } from "@linhey/rhine-design";
import type { HierarchyScene } from "../types";
import { dragLayerCamera, INITIAL_LAYER_CAMERA, layerCameraKey, makeLayerPlanes, type LayerCamera } from "../inspect/layerPlanes";
import "./hierarchyLayers.css";

type Props = { scene: HierarchyScene; selectedNodeId?: string | null; onSelect: (id: string) => void; onHover: (id: string | null) => void };
type Drag = { id: number; x: number; y: number; width: number; height: number; camera: LayerCamera; nodeId?: string; moved: boolean };

/** A read-only projection of snapshot geometry; no device input is emitted. */
export function HierarchyLayers({ scene, selectedNodeId, onSelect, onHover }: Props) {
  const [camera, setCamera] = useState({ ...INITIAL_LAYER_CAMERA });
  const [spacing, setSpacing] = useState(24);
  const [size, setSize] = useState({ width: 320, height: 360 });
  const [failedImages, setFailedImages] = useState(new Set<string>());
  const viewport = useRef<HTMLDivElement>(null);
  const drag = useRef<Drag | null>(null);
  const hintId = useId();
  const { planes, omitted, missingImages } = useMemo(() => makeLayerPlanes(scene, selectedNodeId), [scene, selectedNodeId]);
  useEffect(() => { setFailedImages(new Set()); }, [scene]);
  useEffect(() => {
    const element = viewport.current;
    if (!element) return;
    const update = () => setSize({ width: element.clientWidth, height: element.clientHeight });
    update();
    const observer = new ResizeObserver(update);
    observer.observe(element);
    return () => { observer.disconnect(); drag.current = null; };
  }, [planes.length > 0]);
  const width = Number.isFinite(scene.viewport.width) && scene.viewport.width > 0 ? scene.viewport.width : 390;
  const height = Number.isFinite(scene.viewport.height) && scene.viewport.height > 0 ? scene.viewport.height : 844;
  const maxDepth = Math.max(0, ...planes.map(plane => plane.depth));
  const fit = Math.max(0.01, Math.min(size.width / (width + maxDepth * spacing * 0.8), size.height / (height + maxDepth * spacing * 0.35)) * 0.78);
  const failures = missingImages + planes.filter(plane => plane.image && failedImages.has(plane.node.id)).length;
  if (!planes.length) return <EmptyState title="无可显示的图层" description="当前快照没有可见的有效图层，可更新层级后重试。" />;

  return <section className="rhine-layer-viewer" aria-label="3D 分层视图">
    <Stack gap={2}>
      <Inline gap={2} className="rhine-layer-controls">
        <NumberField label="层间距" value={spacing} min={0} max={48} step={4} onValueChange={value => {
          if (value !== null && Number.isFinite(value)) setSpacing(Math.max(0, Math.min(48, value)));
        }} />
        <Button variant="secondary" onClick={() => setCamera({ ...INITIAL_LAYER_CAMERA })}>重置视角</Button>
        <Text variant="caption" tone="muted">{planes.length} 层{omitted > 0 && ` · 另有 ${omitted} 层未显示`}</Text>
      </Inline>
      <div ref={viewport} className="rhine-layer-viewport" tabIndex={0} role="group" aria-label="旋转图层画布" aria-describedby={hintId}
        data-camera-x={camera.x.toFixed(2)} data-camera-y={camera.y.toFixed(2)}
        onKeyDown={event => {
          if (event.target !== event.currentTarget) return;
          const next = layerCameraKey(camera, event.key);
          if (next) { event.preventDefault(); setCamera(next); }
        }}
        onPointerDown={event => {
          if (!event.isPrimary || event.button !== 0) return;
          const rect = event.currentTarget.getBoundingClientRect();
          const node = (event.target as Element).closest<HTMLElement>("[data-layer-node]");
          drag.current = { id: event.pointerId, x: event.clientX, y: event.clientY, width: rect.width, height: rect.height,
            camera, nodeId: node?.dataset.layerNode, moved: false };
          event.currentTarget.setPointerCapture(event.pointerId);
          event.currentTarget.focus({ preventScroll: true });
        }}
        onPointerMove={event => {
          const current = drag.current;
          if (!current || current.id !== event.pointerId) return;
          const dx = event.clientX - current.x, dy = event.clientY - current.y;
          current.moved ||= Math.hypot(dx, dy) > 4;
          if (current.moved) setCamera(dragLayerCamera(current.camera, dx, dy, current.width, current.height));
        }}
        onPointerUp={event => {
          const current = drag.current;
          if (!current || current.id !== event.pointerId) return;
          drag.current = null;
          if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId);
          if (!current.moved && current.nodeId) onSelect(current.nodeId);
        }}
        onPointerCancel={() => { drag.current = null; }} onLostPointerCapture={() => { drag.current = null; }}
        onPointerLeave={() => { onHover(null); }}>
        <div className="rhine-layer-stack" style={{ width, height,
          transform: `translate(-50%, -50%) scale(${fit}) rotateX(${camera.x}deg) rotateY(${camera.y}deg)` }}>
          {planes.map(({ node, depth, image }) => {
            const imageFailed = failedImages.has(node.id);
            const hasImage = Boolean(image && !imageFailed);
            return <button type="button" className="rhine-layer-plane" key={node.id} data-layer-node={node.id}
              data-material={hasImage ? "solo" : "outline"} aria-pressed={selectedNodeId === node.id}
              aria-label={`选择图层：${node.name || node.type}${hasImage ? "" : "（无独立截图）"}`}
              tabIndex={selectedNodeId === node.id ? 0 : -1}
              style={{ left: node.frame.x, top: node.frame.y, width: node.frame.width, height: node.frame.height,
                transform: `translateZ(${(depth - maxDepth / 2) * spacing}px)`,
                borderRadius: Math.max(0, node.layer?.cornerRadius ?? node.style?.cornerRadius ?? 0) }}
              onPointerEnter={() => { if (!drag.current) onHover(node.id); }}
              onClick={event => { if (event.detail === 0) onSelect(node.id); }}>
              {hasImage && <img src={image} draggable={false} alt="" onError={() => setFailedImages(current => new Set([...current, node.id]))} />}
              {!hasImage && <span className="rhine-layer-outline-name">{node.type}</span>}
            </button>;
          })}
        </div>
      </div>
      <Text id={hintId} variant="caption" tone="muted">拖动画布旋转，点选图层；画布聚焦后用方向键旋转，Home 重置。</Text>
      {failures > 0 && <Text variant="caption" tone="muted">{failures} 层无独立截图，以轮廓显示。</Text>}
      {scene.collection?.limitReasons.length ? <Text variant="caption" tone="muted">当前快照为部分层级：{scene.collection.limitReasons.join("、")}</Text> : null}
    </Stack>
  </section>;
}
