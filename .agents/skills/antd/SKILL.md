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

Use `@ant-design/cli` as the local offline source for Ant Design v4/v5/v6 component metadata, demos, tokens, semantic selectors, changelogs, and migration guidance.

## Setup

Before first use:

```bash
which antd || npm install -g @ant-design/cli
```

If any command reports "Update available", run:

```bash
antd upgrade
```

Always prefer `--format json` for agent parsing.

## Core Rules

1. Query before writing. Do not guess antd APIs from memory.
2. Match the project's antd version with `--version <v>` when known.
3. Use `antd info`, `antd demo`, `antd token`, and `antd semantic` before component implementation.
4. Use `antd env`, `antd doctor`, and `antd lint` for debugging.
5. Use `antd migrate` and `antd changelog` before migration advice.
6. After code changes, run `antd lint` on changed files or relevant source roots.
7. Preview bug reports with `--format json`; submit only after user confirmation.

## Reference Routing

Start with [references/feature-index.md](references/feature-index.md) to map the requested feature to the smallest reference file. Then read only the matched reference(s).

## Common Commands

```bash
antd design.md --format json
antd info Button --format json
antd demo Button basic --format json
antd token Button --format json
antd semantic Button --format json
antd doc Table --format json
antd usage ./src --format json
antd lint ./src --format json
antd env --format json
antd doctor --format json
antd migrate 4 5 --format json
antd changelog 5.21.0..5.24.0 --format json
```

## Global Flags

| Flag | Purpose |
|---|---|
| `--format json` | Agent-readable structured output |
| `--version <v>` | Query a specific AntD version |
| `--lang zh` | Chinese docs |
| `--detail` | Include extra fields |
| `-V`, `--cli-version` | Print CLI version |
