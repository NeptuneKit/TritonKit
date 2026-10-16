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

Check results must include an explicit target version before interpreting `updateAvailable=false` as up to date. Older CLI releases can return false without querying any version source for Homebrew installs. If target/latest is missing, treat the result as unknown and resolve the latest GitHub Release separately. Do not infer a user's installed version from a maintainer machine.

The corrected update flow resolves the release target even for Homebrew check/dry-run. Lookup failures are errors. Execution refreshes Homebrew metadata, requires the formula version to match the selected release, then checks the installed CLI's actual `version --json` output. A stale or different formula reports `homebrew_version_mismatch`; an unexpected installed binary reports `installed_version_mismatch`. Neither is successful version alignment, and skills installation stops. Homebrew does not support installing an arbitrary historical release through this command.

CLI updates do not automatically update skills. When both are requested, use `--include-skills --skills-dir <agent-skills-root>` for each configured skills root. Success requires the actual CLI and the bundle's BUILD_INFO, skill entries, and individual skill metadata to match the selected release; `skills_version_mismatch` rejects inconsistent bundles before installation. Verify `installedVersion` on execution as well as `skillsUpdated` and bundle metadata. `currentVersion` describes the process before the update. A check/dry-run is not installation evidence. On failure, inspect `cliUpdateAttempted`, `updated`, and `installedVersion`: a CLI upgrade can already have completed before a later skills failure. Preserve local files and resolve that failure without assuming nothing changed.


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

First inspect `triton schema --command update --json` and the installed version. The guarded installer described here must be present in that CLI; a command name or this development skill alone does not prove an older released binary implements it. When supported and the agent skills directory is known, preview the plan, then apply the authorized update:

```sh
triton update --include-skills --skills-dir "$AGENT_SKILLS_DIR" --dry-run --json
triton update --include-skills --skills-dir "$AGENT_SKILLS_DIR" --yes --json
```

The guarded installer verifies `tritonkit-skills.tar.gz` against `tritonkit_checksums.txt` from the same selected release, validates the complete archive, stages the bundle, and checks installed file hashes against `.triton-install.json`. Local additions, edits, deletions, or a differing installation without a baseline cause refusal. Do not delete the receipt, remove the existing bundle, or retry with a forceful manual replacement to bypass that refusal. The CLI dry-run is a plan preview; it does not perform the downloaded archive and installed-file validation that the Python dry-run below performs.

Installation uses an exclusive update lock and an atomic directory exchange, writes a private installation receipt, and retains the previous bundle in `.triton-skills-backup-*`. Staged files use private permissions; retain backups rather than treating them as disposable update debris. A failed post-exchange step can leave the new bundle installed with the old bundle retained at a stage/backup path: inspect both before retrying. Skills can update even when the CLI binary is already at the selected version; verify `skillsUpdated=true` and the installed bundle metadata.

1. Download `tritonkit-skills.tar.gz` and `tritonkit_checksums.txt` from the same GitHub Release as the CLI; use the manifest's expected SHA-256 for that archive.
2. Locate the user's configured agent skills directory. For Codex this is usually under the configured `CODEX_HOME` skills directory; if the path is not known, ask the user or inspect the local agent configuration.
3. Preserve old top-level public skill installs. The guarded installer migrates only empty or byte-identical legacy folders to `.triton-skills-legacy-*`; local changes cause refusal and require resolving the conflict first.
4. Validate and install the whole bundle through the guarded installer. Do not remove the installed directory before staging or exchange.
5. Verify:
   - `TritonKit.skills/BUILD_INFO.json` exists.
   - `BUILD_INFO.json.version` matches the intended release.
   - `TritonKit.skills/tritonkit-update/SKILL.md` exists.
   - Every bundled public skill `metadata.version` matches the intended release.

If the installed CLI lacks this contract, use the matching repository's guarded Python installer after confirming its supported flags. From that checkout, with `EXPECTED_SKILLS_SHA256` set to the checksum manifest entry:

```sh
python3 docs-linhay/scripts/install-public-skills.py "$AGENT_SKILLS_DIR" --from-tar "$SKILLS_ARCHIVE" --sha256 "$EXPECTED_SKILLS_SHA256" --dry-run
python3 docs-linhay/scripts/install-public-skills.py "$AGENT_SKILLS_DIR" --from-tar "$SKILLS_ARCHIVE" --sha256 "$EXPECTED_SKILLS_SHA256"
```

The Python dry-run validates the archive and installed/legacy baselines without changing installation files. If validation fails, preserve the installed files and resolve the reported conflict; do not use extract-and-replace instructions. Cross-skill references require all four bundled skills; do not copy individual `SKILL.md` files alone.

## Update App Dependencies

SwiftPM users update the package dependency to the release tag, for example `v0.1.24`. `Package.swift` itself does not contain a TritonKit version field.

CocoaPods users should update pod repo metadata and install the matching pod version:

```sh
pod repo update
pod install
```

The app Podfile should depend on `TritonKit` only, with Debug-only configuration. Do not ask users to add any sibling TritonKit pod.

## Report Back

Report the installed CLI and skills bundle versions, checksum/baseline validation outcome, retained backup and legacy migration outcome, and whether app dependencies were updated or only left as instructions. Separate a dry-run plan from a completed installation.
