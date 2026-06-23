---
name: antd
description: >
  Use when the user's task involves Ant Design (antd) — writing antd components,
  debugging antd issues, querying antd APIs/props/tokens/demos, migrating between
  antd versions, or analyzing antd usage in a project. Triggers on antd-related
  code, imports from 'antd', or explicit antd questions.
allowed-tools:
  - Bash(antd *)
  - Bash(antd bug*)
  - Bash(antd bug-cli*)
  - Bash(antd upgrade*)
  - Bash(npm install -g @ant-design/cli*)
  - Bash(which antd)
---

# Ant Design CLI

You have access to `@ant-design/cli` — a local CLI tool with bundled antd metadata for v4/v5/v6 (plus migration guides for v3 → v4, v4 → v5, v5 → v6). Use it to query component knowledge, analyze projects, and guide migrations. All data is offline, no network needed.

## Setup

Before first use, check if the CLI is installed. If not, install it automatically:

```bash
which antd || npm install -g @ant-design/cli
```

After running any command, if the output contains an "Update available" notice, run `antd upgrade` to update before continuing.


**Always use `--format json` for structured output you can parse programmatically.**

## GetTokens Ant Design design-language contract

When a GetTokens task says “对齐 AntD”, “只保留 AntD”, “AntD 设计语言”, or links to Ant Design spec pages such as docs/spec/introduce-cn or docs/spec/colors-cn, treat it as a design-system contract, not just a component-library import.

Use this source order:

1. Run `antd design.md --format json` for the executable local baseline.
2. Read official Ant Design spec pages when network is available.
3. Query component docs through `antd info`, `antd doc`, `antd token`, or `antd semantic` before changing component code.

The default Ant Design v6 design-language baseline for GetTokens is:

- Values: Natural, Certain, Meaningful, Growing. Prefer predictable, state-clear, purpose-driven enterprise UI over decorative custom styling.
- Color: only Ant Design palette colors are allowed in runtime color literals. Use primary #1677FF, success #52C41A, warning #FAAD14, error/red #FF4D4F / #F5222D, info #1677FF, preset palettes from @ant-design/colors, and neutral colors #FFFFFF, #FAFAFA, #F5F5F5, #F0F0F0, #D9D9D9, #BFBFBF, #8C8C8C, #595959, #434343, #262626, #1F1F1F, #141414, #000000. Do not mint provider, chart, accent, or status colors outside this set. Transparent overlays and shadows should derive from black alpha or color-mix() with an allowed palette color.
- Typography: default product UI uses 14px body text, system font stack, and only 400 / 600 weights for chrome. Avoid 500/650/700+ as product UI emphasis unless an AntD component token requires it.
- Spacing: snap layout gaps and padding to the 4px grid. Avoid arbitrary one-off spacing unless it comes from an AntD component token.
- Radius: controls use 6px, surfaces use 8px, small tags/chips use 4px, pill radius is reserved for avatars/badges/dots.
- Elevation: flat-first. Borders and tonal contrast carry hierarchy; shadows are for genuinely floating surfaces such as modal/dropdown/popover.
- Components: prefer AntD components and AntD component tokens. Primary buttons are reserved for the single dominant action per surface; secondary actions should be default/text variants.

For GetTokens implementation, encode this contract in tests or static gates when possible. A change is not complete if it only imports AntD while preserving custom visual language, arbitrary colors, non-AntD radii, or old GetTokens visual primitives.

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

## Scenarios

### 1. Writing antd component code

Before writing any antd component code, look up its API first — don't rely on memory.

```bash
# Check what props are available
antd info Button --format json

# Get a working demo as starting point
antd demo Button basic --format json

# Check semantic classNames/styles for custom styling
antd semantic Button --format json

# Check component-level design tokens for theming
antd token Button --format json

# Get the overall design language (design.md): colors, typography, spacing, radius + principles
antd design.md --format json
```

**Workflow:** `antd info` → understand props → `antd demo` → grab a working example → write code.

### 2. Looking up full documentation

When you need comprehensive component docs (not just props):

```bash
antd doc Table --format json        # full markdown docs for Table
antd doc Table --lang zh            # Chinese docs
```

### 3. Debugging antd issues

When code isn't working as expected or the user reports an antd bug:

```bash
# Collect full environment snapshot (system, deps, browsers, build tools)
antd env --format json

# Check if the prop exists for the user's antd version
antd info Select --version 5.12.0 --format json

# Check if the prop is deprecated
antd lint ./src/components/MyForm.tsx --format json

# Diagnose project-level configuration issues
antd doctor --format json
```

**Workflow:** `antd env` → capture full environment → `antd doctor` → check configuration → `antd info --version X` → verify API against the user's exact version → `antd lint` → find deprecated or incorrect usage.

### 4. Migrating between versions

When the user wants to upgrade antd (e.g., v3 → v4 or v4 → v5):

```bash
# Get full migration checklist
antd migrate 3 4 --format json    # v3 → v4
antd migrate 4 5 --format json    # v4 → v5

# Check migration for a specific component
antd migrate 4 5 --component Select --format json

# Generate agent-friendly auto-migration prompt (does not modify files)
antd migrate 4 5 --apply ./src --format json

# See what changed between two versions
antd changelog 4.24.0 5.0.0 --format json

# See changes for a specific component
antd changelog 4.24.0 5.0.0 Select --format json
```

**Workflow:** `antd migrate` → get full checklist → `antd changelog <v1> <v2>` → understand breaking changes → apply fixes → `antd lint` → verify no deprecated usage remains.

### 5. Analyzing project antd usage

When the user wants to understand how antd is used in their project:

```bash
# Scan component usage statistics
antd usage ./src --format json

# Filter to a specific component
antd usage ./src --filter Form --format json

# Lint for best practice violations
antd lint ./src --format json

# Check only specific rule categories
antd lint ./src --only deprecated --format json
antd lint ./src --only a11y --format json
antd lint ./src --only performance --format json
```

### 6. Checking changelogs and version history

When the user asks about what changed in a version:

```bash
# Specific version changelog
antd changelog 5.22.0 --format json

# Version range (both ends inclusive)
antd changelog 5.21.0..5.24.0 --format json
```

### 7. Exploring available components

When the user is choosing which component to use:

```bash
# List all components with categories
antd list --format json

# List components for a specific antd version
antd list --version 5.0.0 --format json
```

### 8. Collecting environment info

When you need to understand the project's antd setup, or prepare info for a bug report:

```bash
# Full environment snapshot (text — paste into GitHub Issues)
antd env

# Structured JSON for programmatic use
antd env --format json

# Scan a specific project directory
antd env ./my-project --format json
```

Collects: OS, Node, package managers (npm/pnpm/yarn/bun/utoo), npm registry, browsers, core deps (antd/react/dayjs), all `@ant-design/*` and `rc-*` packages, and build tools (umi/vite/webpack/typescript/etc.).

### 9. Reporting antd bugs

When the user asks you to report an antd bug:

```bash
# Step 0: Collect environment info for reference (optional — antd bug already embeds basic env)
# Use the output to cross-check versions or attach extra details to the bug report
antd env --format json

# Step 1: Preview for user review
antd bug --title "DatePicker crashes when selecting date" \
  --reproduction "https://codesandbox.io/s/xxx" \
  --steps "1. Open DatePicker 2. Click a date" \
  --expected "Date is selected" \
  --actual "Component crashes with error" \
  --format json

# Step 2: Show to user, ask for confirmation

# Step 3: Submit after user confirms
antd bug --title "DatePicker crashes when selecting date" \
  --reproduction "https://codesandbox.io/s/xxx" \
  --steps "1. Open DatePicker 2. Click a date" \
  --expected "Date is selected" \
  --actual "Component crashes with error" \
  --submit
```

### 10. Reporting CLI issues

When the user asks you to report a CLI bug, or explicitly requests help filing one:

```bash
# Preview the bug report for the user
antd bug-cli --title "antd info Button returns wrong props for v5.12.0" \
  --description "When querying Button props for version 5.12.0, the output includes props that don't exist in that version" \
  --steps "1. Run: antd info Button --version 5.12.0 --format json" \
  --expected "Props matching antd 5.12.0 Button API" \
  --actual "Props include 'classNames' which was added in 5.16.0" \
  --format json
```

Show the report to the user and confirm before submitting:

```bash
antd bug-cli --title "antd info Button returns wrong props for v5.12.0" \
  --description "..." \
  --steps "..." \
  --expected "..." \
  --actual "..." \
  --submit
```

**Opt-out:** If the environment variable `ANTD_NO_AUTO_REPORT=1` is set, skip all bug-reporting suggestions entirely — do not suggest `antd bug` or `antd bug-cli` unless the user directly asks.

### 11. Upgrading the CLI

When the user wants to update `@ant-design/cli` to the latest version, or when an "Update available" notice appears:

```bash
# Upgrade to the latest version (auto-detects package manager)
antd upgrade
```

The command detects which package manager installed the CLI (npm, yarn, pnpm, bun, cnpm, utoo) and runs the appropriate upgrade command. If detection fails, it suggests the manual command.

### 12. Using as MCP server

If working in an IDE that supports MCP (Claude Desktop, Cursor, etc.), the CLI can also run as an MCP server, exposing all knowledge-query tools directly:

```json
{
  "mcpServers": {
    "antd": {
      "command": "antd",
      "args": ["mcp", "--version", "5.20.0"]
    }
  }
}
```

This provides 8 tools (`antd_list`, `antd_info`, `antd_doc`, `antd_demo`, `antd_token`, `antd_design_md`, `antd_semantic`, `antd_changelog`) and 2 prompts (`antd-expert`, `antd-page-generator`) via MCP protocol.

## Global Flags

| Flag | Purpose |
|---|---|
| `--format <format>` | Output format: `json`, `text`, or `markdown` (agents should prefer `json`) |
| `--version <v>` | Target a specific antd version (e.g. `5.20.0`) |
| `--lang zh` | Chinese output (default: `en`) |
| `--detail` | Include extra fields (description, since, deprecated, FAQ) |
| `-V, --cli-version` | Print CLI version and exit |

## Key Rules

1. **Always query before writing** — Don't guess antd APIs from memory. Run `antd info` first.
2. **Match the user's version** — Knowledge queries (`list/info/doc/demo/token/semantic/changelog`) support antd v4+. If the project uses antd 4.x/5.x/6.x, pass `--version 4.24.0` / `5.24.0` / `6.x`. For antd v3 projects, use `antd migrate 3 4` first.
3. **Use `--format json`** — Every command supports it. Parse the JSON output rather than regex-matching text output.
4. **Check before suggesting migration** — Run `antd changelog <v1> <v2>` and `antd migrate` before advising on version upgrades.
5. **Lint after changes** — After writing or modifying antd code, run `antd lint` on the changed files to catch deprecated or problematic usage.
6. **Report antd bugs** — When the user asks to report an antd bug, use `antd bug`. Always preview first, get user confirmation, then submit.
7. **Report CLI issues** — When the user asks about a CLI problem, use `antd bug-cli` to help them file a report. Always preview first, get user confirmation, then submit.
