## TritonKit Web AntD refactor notes

This section captures the AntD reference material and implementation lessons from the TritonKit Web mock refactor on 2026-06-21/22.

Primary sources to consult before implementing:

1. Local executable design baseline: `antd design.md --format json`.
2. Official Ant Design introduction/spec page: `https://ant.design/docs/spec/introduce-cn/`.
3. Component API docs from the local CLI: `antd info <Component> --format json`; use `antd doc <Component> --lang zh --format json` when behavior or examples matter.
4. Post-change checks: `antd usage Web/src --format json` and `antd lint Web/src --format json`.

Design facts used in the TritonKit Web migration:

- Official design values are 「自然」「确定性」「意义感」「生长性」. For TritonKit Web, this means predictable inspection surfaces, explicit selected/loading/error states, evidence-first hierarchy, and scalable dense tool UI rather than decorative chrome.
- Use the AntD v6 default primary seed `#1677FF`, success `#52C41A`, warning `#FAAD14`, error `#FF4D4F`; avoid inventing one-off accent/status colors in runtime UI.
- Base product UI typography should stay around 14px with 400/600 weights; avoid custom 500/700 emphasis unless a component token requires it.
- Layout gaps and padding should follow the 4px grid. Prefer AntD component spacing/tokens or small multiples of 4px.
- Controls default to 6px radius, surfaces to 8px, small tags/chips to 4px. Use flat-first hierarchy; reserve shadows for actually floating surfaces.

TritonKit Web component mapping from the refactor:

- Global shell: `ConfigProvider` + `Layout`.
- Toolbar and actions: `Button`; primary buttons should remain rare and reserved for one dominant action per surface.
- Search and local inputs: `Input`; in happy-dom tests, bind both `onInput` and `onChange` when tests dispatch native `input/change` events manually.
- Panels and cards: `Card`.
- Right-side evidence panes: `Tabs`.
- Hierarchy navigation: `Tree`, while preserving data-node attributes and aria/state needed by tests and DTO traceability.
- Runtime/evidence facts: `Descriptions`.
- Status/source labels: `Tag`.

Version and test caveats observed:

- AntD v6 emitted a runtime warning that `List` is deprecated in this environment; avoid introducing `List` for new TritonKit Web code unless `antd info List --format json` confirms the target version supports it without deprecation.
- AntD components may require browser globals not present in happy-dom. For DOM tests, install `ShadowRoot` and `ResizeObserver` polyfills before rendering AntD components.
- Import `antd/dist/reset.css` once from the Web entrypoint. Do not import reset CSS per component.
- AntD can materially increase Vite bundle size. If production Web scope expands, consider route-level `dynamic import()` or Rollup `manualChunks`; do not treat the chunk warning alone as a functional failure for the current Web mock.
- Keep runtime screenshot canvas, coordinate hit-testing, node overlay geometry, and other machine-readable evidence surfaces custom when AntD abstraction would hide coordinates, DOM attributes, or event semantics needed by automation.
