## CLI Install Contract

Use Homebrew for real-project adoption checks by default:

```bash
brew install NeptuneKit/tap/triton
brew update
brew upgrade triton
```

Use the local release CLI only while TritonKit is pre-release, while validating unreleased source changes, or when Homebrew / GitHub Release assets are unavailable:

```bash
swift build --package-path CLI --scratch-path .build/cli -c release --product triton
.build/cli/release/triton version --json
```

When installing that local build into `~/.local/bin/triton` or another existing `PATH` location, avoid overwriting a path that may be backing a running `triton serve` process. Stop the server first, or use atomic replacement:

```bash
swift build --package-path CLI --scratch-path .build/cli -c release --product triton
cp .build/cli/release/triton ~/.local/bin/triton.new
mv ~/.local/bin/triton.new ~/.local/bin/triton
triton version --json
```

Homebrew installs only the macOS CLI. The app-side embedded runtime still comes from SwiftPM or CocoaPods and must remain DEBUG-only.

Release assets live in `NeptuneKit/TritonKit` GitHub Releases and include arm64/x86_64 CLI archives plus `tritonkit_checksums.txt`. The Homebrew tap is updated from those release assets after `v*` tag releases. If the release or tap is unavailable in a test environment, do not fail the regression setup on Homebrew; use the local release CLI and file a TritonKit issue with the missing distribution evidence.
