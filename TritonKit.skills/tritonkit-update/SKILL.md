---
name: tritonkit-update
description: Use when an external user wants to install, update, or verify TritonKit, including Homebrew CLI upgrades, replacing the bundled TritonKit.skills directory, migrating from old top-level skill folders, or aligning app package dependencies to a TritonKit release tag.
metadata:
  version: 0.1.0-dev
---

# TritonKit Update

Use this public skill to update a user's TritonKit installation. Keep CLI, public skills, and app package dependencies aligned to the same release when possible.

## Identify The Target Version

1. If the user asked for a specific version, use that `v*` tag.
2. Otherwise use the latest GitHub Release from `NeptuneKit/TritonKit`.
3. Do not use an unpublished local commit for external users unless they explicitly want source validation.

## Update The CLI

When `triton update` is available, prefer the CLI-managed flow first because it emits a machine-readable plan and keeps Homebrew/manual install boundaries explicit:

```sh
triton update --check --json
triton update --dry-run --json
triton update --yes --json
```

For a pinned release:

```sh
triton update --version v0.1.24 --yes --json
```

For Homebrew-managed installs, `triton update` must use Homebrew and must not overwrite the Cellar binary directly.

Prefer Homebrew:

```sh
brew update
brew upgrade neptunekit/tap/triton
```

For first install:

```sh
brew install NeptuneKit/tap/triton
```

Verify:

```sh
triton version --json
triton web --print-command --json
```

The Web launch plan should report `mode=packaged` for a released Homebrew install.

## Update Public Skills

When `triton update` is available and the agent skills directory is known, prefer:

```sh
triton update --include-skills --skills-dir "$AGENT_SKILLS_DIR" --yes --json
```

This downloads `tritonkit-skills.tar.gz` from the same release as the CLI and replaces the installed `TritonKit.skills/` bundle.

1. Download `tritonkit-skills.tar.gz` from the same GitHub Release as the CLI.
2. Locate the user's configured agent skills directory. For Codex this is usually under the configured `CODEX_HOME` skills directory; if the path is not known, ask the user or inspect the local agent configuration.
3. Remove old pre-bundle top-level installs if present:
   - `tritonkit-dev-feedback`
   - `tritonkit-emulator-cli-takeover`
   - `tritonkit-real-project-regression`
   - `tritonkit-update`
4. Replace the installed `TritonKit.skills/` directory with the extracted bundle from `tritonkit-skills.tar.gz`.
5. Verify:
   - `TritonKit.skills/BUILD_INFO.json` exists.
   - `BUILD_INFO.json.version` matches the intended release.
   - `TritonKit.skills/tritonkit-update/SKILL.md` exists.
   - Every bundled public skill `metadata.version` matches the intended release.

When the TritonKit repository is available locally, prefer:

```sh
docs-linhay/scripts/install-public-skills.sh "$AGENT_SKILLS_DIR" --from-tar tritonkit-skills.tar.gz
```

Without the repository, extract the tarball to a temporary directory and copy the extracted `TritonKit.skills/` directory into the agent skills directory.

## Update App Dependencies

SwiftPM users update the package dependency to the release tag, for example `v0.1.24`. `Package.swift` itself does not contain a TritonKit version field.

CocoaPods users should update pod repo metadata and install the matching pod version:

```sh
pod repo update
pod install
```

The app Podfile should depend on `TritonKit` only, with Debug-only configuration. Do not ask users to add `TritonKitShared` directly; `TritonKit.podspec` resolves it transitively.

## Report Back

Report the installed CLI version, the installed skills bundle version, whether old top-level skill directories were removed, and whether app dependencies were updated or only left as instructions.
