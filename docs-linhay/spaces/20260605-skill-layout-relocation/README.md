# 2026-06-05 skill layout relocation

## Background

TritonKit-owned skills were previously split under `.agents/tritonkit-skills/public/` and `.agents/tritonkit-skills/internal/`, with `.agents/skills/` holding discovery symlinks. The new layout separates the external distribution source from repository development skills more directly.

## Goals

- Move public, externally distributed skills to `TritonKit.skills/`.
- Move TritonKit repository development skills to real directories under `.agents/skills/`.
- Remove `.agents/tritonkit-skills/` as the canonical source directory.
- Keep release packaging limited to public skills and keep internal skills out of `tritonkit-skills.tar.gz`.
- Reference `harmony-next.skills` for a script-driven skill package flow with package build metadata, while preserving TritonKit's combined tar.gz release asset.

## Non-goals

- No CLI behavior changes.
- No skill content rewrite beyond path and governance wording.
- No Web/Wails or runtime changes.

## BDD

### Scenario 1: release packages public skills from the new root

Given the release workflow packages `tritonkit-skills.tar.gz`
When it copies public skill sources
Then it reads from `TritonKit.skills/<skill-name>/`
And it includes `tritonkit-dev-feedback`, `tritonkit-emulator-cli-takeover`, and `tritonkit-real-project-regression`.

### Scenario 2: repository development skills are local agent skills

Given TritonKit maintainers use project development skills
When the local agent scans `.agents/skills/`
Then internal skills are real skill directories there
And public release skills are not required to be symlinked through `.agents/skills/`.

### Scenario 3: old skill source root is retired

Given a maintainer checks the repository layout
When they look for TritonKit-owned skill sources
Then `.agents/tritonkit-skills/` no longer exists
And README, AGENTS, CI classification, and release automation docs point to the new roots.

### Scenario 4: public skill package has build metadata

Given CI packages public TritonKit skills
When it creates `tritonkit-skills.tar.gz`
Then packaging is performed by `docs-linhay/scripts/package-public-skills.py`
And the package contains `BUILD_INFO.json`
And the package remains a combined tar.gz rather than `.skill.zip` or per-skill tarballs.

## Acceptance

- `docs-linhay/scripts/verify-ci-validate-mode.sh` passes.
- `docs-linhay/scripts/verify-release-automation.sh` passes.
- `docs-linhay/scripts/verify-skill-package.sh` passes.
- `docs-linhay/scripts/check-docs.sh` passes.
- `git diff --check` passes.
