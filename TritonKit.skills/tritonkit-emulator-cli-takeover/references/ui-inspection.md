# UI details, node images and 3D inspection

## Prerequisites

Deep live details require an opted-in Debug UIKit embedded runtime, not merely host AX or a visible WebView container. Select its exact target from `triton list --json`. Hierarchy must be enabled; node images additionally require screenshot capability. Release remains no-op.

```bash
triton debug runtime manifest --target '<runtime-target>' --json
triton schema --command debug.details --compact --json
triton debug hierarchy --target '<runtime-target>' --json
```

Keep App runtime instance and current node IDs together. An OID is process-local; never reuse it after restart or derive it from a host AX alias.

## Workflow

1. Read the hierarchy and choose a current view/layer OID. Request attributes/geometry without images first when pixels are unnecessary:

```bash
triton debug details --target '<runtime-target>' --oid <oid> --screenshots none --json
triton debug attrs --target '<runtime-target>' --oid <oid> --json
```

2. For a visual inspection, choose `none`, `solo`, `group` or `both`. Repeat `--oid` for 1–8 unique nonzero IDs; the per-image default is 262144 pixels, maximum 1048576.

```bash
triton debug details --target '<runtime-target>' --oid <oid> --screenshots both --max-pixel-count 262144 --json
```

- `group` includes the layer and drawable descendants.
- `solo` renders the current layer with its direct child layers temporarily hidden; restoration occurs in the runtime's synchronous transaction. It is not an independent screenshot of every child.
- Keep `soloScreenshotRef` and `groupScreenshotRef` distinct. Legacy `screenshotRef` means subtree/group compatibility, not solo.
- A raw CALayer has no UIView identity merely because its delegate is a view. Geometry may be local when no window binding exists.

3. Use the existing readonly Web hierarchy inspector for its tree/plane selection and 3D view. Drag or use direction keys to rotate, adjust layer spacing, and use Home to reset. This is a projection of axis-aligned screen frames and depth; missing images are shown as outlines with explicit missing-image state. Follow [Web preview](web-preview.md) for actual startup, rather than inventing a `3d` CLI command.

4. Optional annotations and guarded selection have separate workflows: [view highlight](view-highlight.md) and the regression skill's picker/selection instructions. Do not treat selection alone as permission to click or property mutation as read-only inspection.

## Verification

Inspect `ok`, `partial`, top-level error and each item's `failureReason`. Attributes/geometry may be usable while image collection failed; zero/default geometry on a stale OID is not successful node evidence. Preserve raw PNG fallback when an upload fails and inspect image budgets/metadata before claiming pixels were captured.

Budgets include 4194304 aggregate requested pixels, 4194304 PNG bytes and cooperative deadline checks between nodes/images. A single native render/encode is not preemptible; timeout can leave outcome unknown. Do not repeat rendering or input automatically to repair an uncertain operation.

For native acceptance, use an authorized App-hosted iOS destination to check actual pixels, state restoration, bare-layer geometry and capability-disabled/Release behavior. A macOS test skipped by `canImport(UIKit)`, a rendered HTML fixture, or a complete scene JSON is not native pixel acceptance.

## Limits

The 3D inspector shows at most 200 visible planes; it does not reconstruct transform3D, perspective, masks or compositor effects. `CALayer.render` cannot guarantee Metal/video/remote WebView pixel equivalence. SwiftUI exposure is the UIKit/CALayer runtime representation, not a complete SwiftUI semantic tree.

No LookinServer/Peertalk/NSKeyedArchiver service is required. Arbitrary object-method consoles, full SwiftUI semantics, and new Web write endpoints are not supplied. Keep host-composited full-screen captures separate from embedded App-layer/node images in [evidence validation](validation.md).
