---
name: tritonkit-web-mock-ui
description: Use when designing, implementing, or validating TritonKit Web mock UI screens, React/Vite prototypes, design evidence, and browser smoke checks without turning Web into the business-control surface.
metadata:
  version: 0.1.0-dev
---

# TritonKit Web Mock UI

## Trigger

Use this skill when the user asks for a Web UI mock, dashboard concept, browser prototype, design iteration, or React/Vite implementation for TritonKit.

Do not use it for CLI / HTTP contract work unless the request also needs a human-facing Web mock.

## Product Boundary

- CLI and HTTP remain the business-control contract.
- Web mock screens consume DTO-shaped mock data or read-only endpoints by default.
- Do not introduce create / update / delete / execute / approve / deny control loops in Web first.
- Do not treat `Web/` as Wails revival or active production UI unless a new space explicitly changes that boundary.

## Required Setup

1. Create or update a `docs-linhay/spaces/<space-key>/README.md` before code.
2. Include BDD scenarios, scope, out-of-scope, technology choices, and validation method.
3. Use `Web/` for the repo-tracked React / TypeScript / Vite mock app unless the space states a different location.
4. Keep Vite ports aligned with repo policy:

   ```text
   dev:     127.0.0.1:34127
   preview: 127.0.0.1:34128
   strictPort: true
   ```

5. Keep generated output untracked:
   - `Web/node_modules/`
   - `Web/dist/`
   - screenshots directories

## Implementation Pattern

- Prefer React + TypeScript + Vite for interactive mocks.
- Keep mock DTOs in a small data module such as `Web/src/data/mockData.ts`.
- Keep top-level state and page composition in `Web/src/App.tsx`.
- Use icons from `lucide-react`.
- Build the real tool screen first, not a landing page.
- When a visible label depends on runtime state such as foreground app name, bundle id, hierarchy owner, readiness, or command result, first confirm the CLI / HTTP DTO exposes a machine-readable field. Web may pass through optional fields and show honest unknown/fallback states, but must not invent app identity, hierarchy source, or business status from emulator type, screenshot pixels, or static mock names.
- If a human-facing Web mock reveals a missing CLI / HTTP field, preserve the optional field in the Web bridge where useful, add a clear fallback label, and file or link a development feedback issue for the missing machine-readable contract.
- For TritonKit emulator work, default information architecture is:
  - target list
  - device mirror
  - target inspector
  - actions
  - network evidence
  - logs

## Device Canvas Interaction Pattern

- When the Web canvas mirrors a real screenshot and proxies device input, keep the machine action boundary in Triton CLI / HTTP. The Web UI may collect human gestures, but it should emit DTO-shaped `tap`, `swipe`, `type`, `paste`, `deleteBackward`, or similar input payloads instead of calling platform tools directly.
- Do not infer focused App controls from screenshot pixels. A tap on the canvas may open a local keyboard relay, but whether the App focused an input must be determined by the preceding Triton input result, runtime state, screenshot, AX, or other machine-readable evidence.
- For keyboard entry on a screenshot canvas, prefer a visible focused relay input near the tap point over relying only on `keydown` on a generic `div`. This preserves browser text editing behavior, IME composition direction, paste, selection deletion, and Backspace/Delete semantics.
- Keep relay semantics explicit:
  - appended text maps to `type`;
  - paste maps to `paste`;
  - deletion maps to repeated `deleteBackward`;
  - Escape or an equivalent UI action dismisses only the relay, not the remote App state.
- Tests should cover the relay at the DOM payload level: tap creates/focuses the relay, typed text emits `type`, deletion emits `deleteBackward`, and paste emits `paste` without requiring a real device.

## Evidence Panel Interaction Pattern

- Network and log evidence are separate panes. If users can hide them, keep independent state for each pane rather than coupling all evidence visibility to a single logs toggle.
- Every hidden evidence pane needs a visible restore path. If both network and logs are hidden, render a compact restore strip with explicit controls such as `显示网络` and `显示日志`.
- Keep evidence pane controls as UI state only. Hiding network/log strips must not stop capture, mutate backend state, or change CLI/HTTP evidence contracts unless a separate requirement explicitly adds that control loop.

## Validation

Run these before delivery:

```bash
npm run build
git diff --check
```

If the dev server is needed:

```bash
npm run dev
```

Then open `http://127.0.0.1:34127/` in a browser automation tool and verify:

- page title and primary screen text are visible;
- console has no errors except known dev-tool informational logs;
- no horizontal overflow at a desktop viewport around 1200 px;
- target/device switching changes visible DTO values;
- screenshot evidence is saved under the corresponding space screenshots directory.

## Documentation

Update:

- the space `README.md`;
- `docs-linhay/memory/YYYY-MM-DD.md`;
- this skill when a new reusable Web mock workflow appears.

Only update `AGENTS.md` when the rule is repo-wide and long-lived.
