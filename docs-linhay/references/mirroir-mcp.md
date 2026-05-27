# Mirroir MCP Reference

## Source

- Repository: `https://github.com/jfarcand/mirroir-mcp`
- Local checkout: `docs-linhay/references/mirroir-mcp/`
- Clone date: 2026-05-27
- Checked HEAD: `7e97f0c`
- License: Apache-2.0

## TritonKit Relevance

This reference is used only for host-side capability research. TritonKit will not adopt mirroir's MCP server or expose a second MCP tool surface.

Useful areas:

1. Host target registry and active target resolution.
2. macOS window discovery and state detection.
3. Window screenshot capture and metadata.
4. Vision OCR / element coordinate extraction.
5. CGEvent-based tap, swipe, drag, type, and key input.
6. Fail-closed permission model for mutating tools.

## Current Decision

Absorb the underlying host-side capabilities into Triton-owned CLI adapters:

```text
triton target ...
triton observe ...
triton screenshot ...
triton tap/swipe/type/press ...
triton evidence ...
```

Do not integrate:

1. MCP JSON-RPC server.
2. MCP `tools/list` / `tools/call` surface.
3. npm wrapper.
4. embacle / Rust FFI / AI vision in the first phase.
5. BFS / DFS exploration or skill generation.

The implementation backlog is tracked in `docs-linhay/spaces/20260527-mirroir-host-adapter/`.
