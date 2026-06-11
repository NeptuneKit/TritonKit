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
- For TritonKit emulator work, default information architecture is:
  - target list
  - device mirror
  - target inspector
  - actions
  - network evidence
  - logs

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
