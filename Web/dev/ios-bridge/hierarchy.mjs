import { runTritonJSON } from "./process.mjs";
import { isIOSRuntimeMirror, resolveIOSRuntimeMirrorTarget } from "./runtimeMirror.mjs";

const defaultRuntimeDataBaseURL = "http://127.0.0.1:19421";

export async function captureHostHierarchy(tritonPath, platform, target, method = "GET", options = {}) {
  const runtimeMirror = isIOSRuntimeMirror(platform, options);
  const hierarchyTarget = runtimeMirror ? await resolveIOSRuntimeMirrorTarget(tritonPath, target, options) : target;
  const args = ["debug", "hierarchy", "--platform", platform, "--target", hierarchyTarget, "--json"];
  let payload;
  try {
    payload = await runTritonJSON(tritonPath, args);
  } catch (error) {
    if (platform === "ios" && shouldFallbackToLegacyIosHierarchy(error)) {
      const legacyTarget = await resolveLegacyIosHierarchyTarget(tritonPath, target, options, hierarchyTarget);
      const legacyPayload = await runTritonJSON(tritonPath, ["debug", "hierarchy", "--target", legacyTarget, "--json"]);
      return attachHierarchyCaptureControl(
        await mapLegacyIosHierarchyToHostResponse(legacyPayload, target, {
          runtimeDataBaseURL: options.runtimeDataBaseURL || defaultRuntimeDataBaseURL,
          commandTarget: legacyTarget,
        }),
        method,
        target
      );
    }
    throw error;
  }
  if (!payload || payload.ok !== true || !payload.scene) {
    throw new Error("triton debug hierarchy did not return a valid HostHierarchyResponse scene");
  }
  return attachHierarchyCaptureControl(
    await hydrateHierarchySceneNodeSlices(payload, options.runtimeDataBaseURL || defaultRuntimeDataBaseURL),
    method,
    target
  );
}

async function resolveLegacyIosHierarchyTarget(tritonPath, target, options, fallbackTarget) {
  try {
    return await resolveIOSRuntimeMirrorTarget(tritonPath, target, options);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (message.includes("No connected iOS App runtime target matched host target")) {
      throw error;
    }
    return fallbackTarget;
  }
}

function shouldFallbackToLegacyIosHierarchy(error) {
  const message = error instanceof Error ? error.message : String(error);
  return message.includes("Unknown option '--platform'") ||
    message.includes("unknown option '--platform'") ||
    message.includes('"code" : "target_not_found"') ||
    message.includes('"code":"target_not_found"') ||
    message.includes("Target not found");
}

function attachHierarchyCaptureControl(payload, method, target) {
  const captureEvidence = hierarchyCaptureEvidence(payload, target);
  return {
    ...payload,
    control: {
      action: "hierarchy.capture",
      entrypoint: "web-dev-bridge",
      method,
      readonly: true,
      mutatesApp: false,
    },
    captureEvidence,
  };
}

function hierarchyCaptureEvidence(payload, target) {
  const nodes = Array.isArray(payload?.scene?.nodes) ? payload.scene.nodes : [];
  const visualSources = nodes.flatMap(hierarchyNodeVisualSources);
  const dataUrlCount = visualSources.filter((source) => source.kind !== "styledFallback" && Boolean(source.dataUrl)).length;
  const realSliceCount = visualSources.filter((source) => source.kind !== "styledFallback" && Boolean(source.dataUrl || source.dataRef)).length;
  const failedNodeCount = visualSources.filter((source) => source.kind !== "styledFallback" && Boolean(source.dataRef) && !source.dataUrl).length;
  const sourceCommand = String(payload?.source?.command ?? "");
  return {
    captureId: hierarchyCaptureId(payload, target, nodes.length, dataUrlCount),
    capturedAt: payload?.capturedAt ?? new Date().toISOString(),
    target: {
      id: target,
      ambiguous: false,
    },
    source: {
      kind: sourceCommand.includes("--platform") ? "triton-hierarchy" : "fallback",
      nodeSlice: realSliceCount > 0 ? "real" : nodes.length > 0 ? "styled" : "none",
      screenshotSlice: dataUrlCount > 0 ? "real" : "none",
    },
    hydration: {
      dataUrlCount,
      nodeCount: nodes.length,
      failedNodeCount,
    },
  };
}

function hierarchyCaptureId(payload, target, nodeCount, dataUrlCount) {
  const capturedAt = String(payload?.capturedAt ?? "");
  return Buffer.from([target, capturedAt, nodeCount, dataUrlCount].join("|")).toString("base64url").slice(0, 24);
}

async function mapLegacyIosHierarchyToHostResponse(payload, target, options = {}) {
  const viewport = resolveLegacyIosViewport(payload);
  const nodes = [];
  const rootItems = Array.isArray(payload?.displayItems) ? payload.displayItems : [];
  for (const item of rootItems) {
    await appendLegacyIosNode(nodes, item, undefined, viewport, options);
  }
  if (nodes.length === 0) {
    throw new Error("legacy iOS hierarchy did not include displayItems[]");
  }
  return {
    ok: true,
    capturedAt: new Date().toISOString(),
    source: {
      command: `triton debug hierarchy --target ${options.commandTarget ?? target} --json`,
      runtimeScope: "runtime-tree",
      readonly: true,
    },
    scene: {
      platform: "ios",
      rootId: nodes[0].id,
      viewport,
      nodes,
      controllerContext: resolveLegacyIosControllerContext(payload?.controllerContext, nodes),
    },
  };
}

function resolveLegacyIosControllerContext(context, nodes) {
  if (context && (context.activeControllerName || Array.isArray(context.stack) && context.stack.length > 0)) {
    return context;
  }
  const controllerNodes = nodes.filter(isLegacyIosControllerNode);
  const active = controllerNodes
    .filter((node) => node.visible)
    .filter((node) => !/UITrackingElementWindowController|UIEditingOverlayViewController/.test(node.type))
    .sort((first, second) => {
      const area = second.frame.width * second.frame.height - first.frame.width * first.frame.height;
      return area === 0 ? second.depth - first.depth : area;
    })[0] ?? controllerNodes[0];
  if (!active) return undefined;
  const entry = legacyIosControllerEntryFromNode(active);
  return {
    activeControllerId: entry.id,
    activeControllerName: entry.name,
    activeControllerClassName: entry.className,
    stack: [entry],
    source: "scene-controller-node-fallback",
  };
}

function isLegacyIosControllerNode(node) {
  return node?.source === "runtime-controller" ||
    node?.raw?.role === "UIViewController" ||
    String(node?.id ?? "").startsWith("ios:controller:");
}

function legacyIosControllerEntryFromNode(node) {
  return {
    id: node.id,
    oid: Number.isFinite(Number(node.raw?.identifier)) ? Number(node.raw.identifier) : undefined,
    className: node.type,
    name: String(node.name ?? node.type).replace(/#\d+$/, "") || node.type,
  };
}

function resolveLegacyIosViewport(payload) {
  const appInfo = payload?.appInfo && typeof payload.appInfo === "object" ? payload.appInfo : {};
  const root = Array.isArray(payload?.displayItems) ? payload.displayItems[0] : null;
  const rootFrame = parseLegacyFrame(root?.frame);
  return {
    width: positiveNumber(appInfo.screenWidth) ?? rootFrame.width ?? 390,
    height: positiveNumber(appInfo.screenHeight) ?? rootFrame.height ?? 844,
  };
}

async function appendLegacyIosNode(nodes, item, parentId, viewport, options, context = {}) {
  if (!item || typeof item !== "object") return;
  const frame = parseLegacyFrame(item.frame);
  if (!frame) return;
  const parentVisible = context.parentVisible !== false;
  const oid = item.layerObject?.oid ?? item.viewObject?.oid ?? nodes.length;
  const controllerOID = item.hostViewControllerObject?.oid;
  const shouldInsertController = controllerOID !== undefined && controllerOID !== null && controllerOID !== context.currentControllerOID;
  const controllerId = shouldInsertController ? `ios:controller:${controllerOID}` : null;
  const depthOffset = Number.isFinite(Number(context.depthOffset)) ? Number(context.depthOffset) : 0;
  if (shouldInsertController) {
    const controllerType = legacyIosControllerClassName(item);
    const controllerName = legacyIosControllerNodeName(item);
    const controllerFrame = clampFrameToViewport(frame, viewport);
    nodes.push({
      id: controllerId,
      parentId,
      type: controllerType,
      name: controllerName,
      frame: controllerFrame,
      depth: Math.max(0, legacyIosNodeDepth(item, parentId) + depthOffset),
      visible: parentVisible && item.isHidden !== true,
      interactive: false,
      color: "#b48cff",
      source: "runtime-controller",
      style: {
        display: "controller",
        text: controllerName,
        backgroundColor: "#b48cff",
        alpha: typeof item.alpha === "number" ? item.alpha : 1,
      },
      visualSources: [
        {
          kind: "styledFallback",
          rect: controllerFrame,
          reason: "UIViewController host object has no standalone view snapshot",
        },
      ],
      raw: {
        platform: "ios",
        source: "runtime-tree",
        role: "UIViewController",
        identifier: String(controllerOID),
      },
      renderHints: {
        preferredMode: "structure",
        fallbackMode: "wireframe",
        quality: "semantic",
      },
    });
  }
  const type = legacyIosClassName(item);
  const id = `ios:runtime:${oid}`;
  const depth = legacyIosNodeDepth(item, parentId) + depthOffset + (shouldInsertController ? 1 : 0);
  const alpha = typeof item.alpha === "number" ? item.alpha : 1;
  const visible = parentVisible && item.isHidden !== true && alpha > 0.01 && frame.width > 0 && frame.height > 0;
  const interactive = legacyIosNodeIsInteractive(type, item);
  const color = legacyIosNodeColor(item, interactive);
  const slice = await legacyIosNodeSlice(item, options);
  const visualSources = hierarchyNodeVisualSources({ frame: clampFrameToViewport(frame, viewport), slice });
  nodes.push({
    id,
    parentId: controllerId ?? parentId,
    type,
    name: legacyIosNodeName(type, oid, item),
    frame: clampFrameToViewport(frame, viewport),
    depth,
    visible,
    interactive,
    color,
    source: "runtime-tree",
    style: legacyIosNodeStyle(item, color, alpha),
    slice,
    visualSources,
    renderHints: legacyIosRenderHints(type, frame, viewport, slice),
  });
  const children = Array.isArray(item.subitems) ? item.subitems : [];
  const childContext = {
    depthOffset: depthOffset + (shouldInsertController ? 1 : 0),
    currentControllerOID: controllerOID ?? context.currentControllerOID,
    parentVisible: visible,
  };
  for (const child of children) {
    await appendLegacyIosNode(nodes, child, id, viewport, options, childContext);
  }
}

function legacyIosNodeDepth(item, parentId) {
  return Number.isFinite(Number(item.indentLevel)) ? Number(item.indentLevel) : parentId ? 1 : 0;
}

function parseLegacyFrame(value) {
  if (!Array.isArray(value) || !Array.isArray(value[0]) || !Array.isArray(value[1])) return null;
  const x = Number(value[0][0]);
  const y = Number(value[0][1]);
  const width = Number(value[1][0]);
  const height = Number(value[1][1]);
  if (![x, y, width, height].every(Number.isFinite)) return null;
  return { x, y, width, height };
}

function positiveNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) && number > 0 ? number : null;
}

function legacyIosClassName(item) {
  return String(
    item.layerObject?.classChainList?.[0] ??
      item.viewObject?.classChainList?.[0] ??
      item.hostViewControllerObject?.classChainList?.[0] ??
      "UIView"
  );
}

function legacyIosControllerClassName(item) {
  return String(item.hostViewControllerObject?.classChainList?.[0] ?? "UIViewController");
}

function legacyIosControllerNodeName(item) {
  const type = legacyIosControllerClassName(item);
  const oid = item.hostViewControllerObject?.oid ?? "unknown";
  const shortType = type.split(".").at(-1) ?? type;
  return `${shortType}#${oid}`;
}

function legacyIosNodeName(type, oid, item) {
  if (item.representedAsKeyWindow) return "keyWindow";
  const title = normalizeOptionalString(item.customDisplayTitle);
  if (title) return title;
  const shortType = type.split(".").at(-1) ?? type;
  return `${shortType}#${oid}`;
}

function legacyIosNodeIsInteractive(type, item) {
  return /(button|control|cell|collection|table|scroll|textfield|textview|switch|slider|segmented)/i.test(type) ||
    (Array.isArray(item.eventHandlers) && item.eventHandlers.length > 0);
}

function legacyIosNodeColor(item, interactive) {
  const background = item.backgroundColor;
  if (background && typeof background === "object" && typeof background.red === "number") {
    const alpha = typeof background.alpha === "number" ? background.alpha : 1;
    if (alpha > 0.03) {
      return rgbFloatToHex(background.red, background.green, background.blue);
    }
  }
  return interactive ? "#2563eb" : "#94a3b8";
}

function rgbFloatToHex(red, green, blue) {
  const toHex = (value) => Math.max(0, Math.min(255, Math.round(Number(value ?? 0) * 255))).toString(16).padStart(2, "0");
  return `#${toHex(red)}${toHex(green)}${toHex(blue)}`;
}

function legacyIosNodeStyle(item, color, alpha) {
  const title = normalizeOptionalString(item.customDisplayTitle);
  return {
    display: legacyIosStyleDisplay(legacyIosClassName(item)),
    text: title ?? undefined,
    backgroundColor: color,
    alpha,
  };
}

function legacyIosStyleDisplay(type) {
  if (/button|control/i.test(type)) return "button";
  if (/label|text/i.test(type)) return "text";
  if (/cell|card/i.test(type)) return "card";
  if (/collection|table|scroll|stack/i.test(type)) return "container";
  if (/navigation|bar/i.test(type)) return "bar";
  return "view";
}

async function legacyIosNodeSlice(item, options) {
  const screenshotRef = normalizeOptionalString(item.screenshotRef);
  if (!screenshotRef) {
    return {
      available: false,
      mode: "node-screenshot-ref",
      source: "triton-runtime-data-ref",
    };
  }
  const dataUrl = await fetchRuntimeDataRefDataUrl(options.runtimeDataBaseURL || defaultRuntimeDataBaseURL, screenshotRef);
  if (!dataUrl) {
    return {
      available: false,
      mode: "node-screenshot-ref",
      source: "triton-runtime-data-ref",
    };
  }
  return {
    available: true,
    mode: "node-screenshot-ref",
    source: "triton-runtime-data-ref",
    dataRef: screenshotRef,
    dataUrl,
  };
}

async function fetchRuntimeDataRefDataUrl(baseURL, screenshotRef) {
  if (typeof fetch !== "function") return null;
  const url = runtimeDataRefURL(baseURL, screenshotRef);
  try {
    const response = await fetch(url);
    if (!response.ok) return null;
    const buffer = Buffer.from(await response.arrayBuffer());
    if (buffer.length === 0) return null;
    const mimeType = imageMimeType(buffer);
    if (!mimeType.startsWith("image/")) return null;
    return `data:${mimeType};base64,${buffer.toString("base64")}`;
  } catch {
    return null;
  }
}

async function hydrateHierarchySceneNodeSlices(payload, runtimeDataBaseURL) {
  const nodes = Array.isArray(payload?.scene?.nodes) ? payload.scene.nodes : [];
  if (nodes.length === 0) return payload;
  const hydratedNodes = await Promise.all(nodes.map(async (node) => {
    const hydratedSlice = await hydrateHierarchyNodeSlice(node, runtimeDataBaseURL);
    const visualSources = await hydrateHierarchyVisualSources({ ...node, slice: hydratedSlice }, runtimeDataBaseURL);
    return {
      ...node,
      slice: hydratedSlice,
      visualSources,
      renderHints: {
        preferredMode: visualSources.some((source) => source.kind === "layerOwnContents") ? "slice" : node.renderHints?.preferredMode ?? "style",
        fallbackMode: node.renderHints?.fallbackMode ?? "style",
        quality: visualSources.some((source) => source.dataUrl || source.dataRef) ? "exact" : node.renderHints?.quality ?? "approximate",
      },
    };
  }));
  return {
    ...payload,
    scene: {
      ...payload.scene,
      nodes: hydratedNodes,
    },
  };
}

async function hydrateHierarchyNodeSlice(node, runtimeDataBaseURL) {
  const dataRef = normalizeOptionalString(node?.slice?.dataRef);
  if (!node?.slice?.available || node.slice.dataUrl || !dataRef) {
    return node?.slice;
  }
  const dataUrl = await fetchRuntimeDataRefDataUrl(runtimeDataBaseURL, dataRef);
  if (!dataUrl) return node.slice;
  return {
    ...node.slice,
    dataUrl,
  };
}

async function hydrateHierarchyVisualSources(node, runtimeDataBaseURL) {
  const sources = hierarchyNodeVisualSources(node);
  return Promise.all(sources.map(async (source) => {
    const dataRef = normalizeOptionalString(source?.dataRef);
    if (!dataRef || source.dataUrl || source.kind === "styledFallback") return source;
    const dataUrl = await fetchRuntimeDataRefDataUrl(runtimeDataBaseURL, dataRef);
    return dataUrl ? { ...source, dataUrl } : source;
  }));
}

function hierarchyNodeVisualSources(node) {
  const explicit = Array.isArray(node?.visualSources) ? node.visualSources.filter(Boolean) : [];
  const legacy = legacySliceVisualSource(node);
  if (!legacy) return explicit;
  const alreadyRepresented = explicit.some((source) =>
    source?.kind === "subtreeSnapshot" &&
    (normalizeOptionalString(source.dataRef) === legacy.dataRef || normalizeOptionalString(source.dataUrl) === legacy.dataUrl)
  );
  return alreadyRepresented ? explicit : [...explicit, legacy];
}

function legacySliceVisualSource(node) {
  if (!node?.slice?.available) return null;
  const dataRef = normalizeOptionalString(node.slice.dataRef);
  const dataUrl = normalizeOptionalString(node.slice.dataUrl);
  if (!dataRef && !dataUrl) return null;
  const rect = node.frame && typeof node.frame === "object"
    ? node.frame
    : { x: 0, y: 0, width: 1, height: 1 };
  return {
    kind: "subtreeSnapshot",
    dataRef: dataRef || undefined,
    dataUrl: dataUrl || undefined,
    rect,
    capturedBy: node.slice.source === "triton-runtime-data-ref" ? "UIView.render" : "unknown",
  };
}

function runtimeDataRefURL(baseURL, screenshotRef) {
  const normalizedBaseURL = String(baseURL || defaultRuntimeDataBaseURL).replace(/\/+$/, "");
  const normalizedRef = String(screenshotRef).replace(/^\/+/, "");
  if (normalizedRef.startsWith("data/")) {
    return `${normalizedBaseURL}/${normalizedRef.split("/").map(encodeURIComponent).join("/")}`;
  }
  return `${normalizedBaseURL}/data/${encodeURIComponent(normalizedRef)}`;
}

function legacyIosRenderHints(type, frame, viewport, slice) {
  if (slice?.available && slice.dataUrl) {
    return { preferredMode: "slice", fallbackMode: "style", quality: "exact" };
  }
  const isFullscreen = frame.width >= viewport.width * 0.96 && frame.height >= viewport.height * 0.9;
  if (isFullscreen && /window|transition|shadow|container|wrapper|root/i.test(type)) {
    return { preferredMode: "wireframe", fallbackMode: "wireframe", quality: "fallback" };
  }
  return { preferredMode: "slice", fallbackMode: "style", quality: "approximate" };
}

function clampFrameToViewport(frame, viewport) {
  return {
    x: Math.max(0, Math.min(viewport.width, frame.x)),
    y: Math.max(0, Math.min(viewport.height, frame.y)),
    width: Math.max(0, Math.min(viewport.width, frame.width)),
    height: Math.max(0, Math.min(viewport.height, frame.height)),
  };
}

function normalizeOptionalString(value) {
  if (value === undefined || value === null) {
    return null;
  }
  const text = String(value).trim();
  return text.length > 0 ? text : null;
}

function imageMimeType(buffer) {
  if (buffer.length >= 8 && buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return "image/png";
  }
  if (buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return "image/jpeg";
  }
  return "application/octet-stream";
}
