# Rockxy Reference

## Source

- Repository: `https://github.com/RockxyApp/Rockxy.git`
- Local snapshot: `docs-linhay/references/rockxy/`
- Snapshot commit: `120a4428feb1a436677c7b8a9c7332f38ae6b0e0`
- Primary README: `docs-linhay/references/rockxy/README.zh.md`
- Local note: upstream `releases/latest.json` is omitted from this reference snapshot because TritonKit docs forbid non-traceable `latest` filenames. Two upstream files named `BreakpointTemplateStore*` are locally renamed to `BreakpointPresetStore*` because the original names accidentally match the same filename guard.

## Why It Matters

Rockxy is a macOS native HTTP debugging proxy implemented in Swift. It is a useful reference for TritonKit's host-side iOS Simulator proxy takeover lane, especially because the current TritonKit decision is to observe and control network traffic through host-side proxy state instead of App-side `URLProtocol`, method swizzling, SDK interceptors, or embedded runtime network providers.

## Useful Reference Areas

- `RockxyHelperTool/ProxyConfigurator.swift`: host-side proxy override, restore, bypass domain handling, active network service detection, and `/usr/sbin/networksetup` integration.
- `Shared/RockxyHelperProtocol.swift`: XPC helper contract for privileged proxy and certificate operations.
- `RockxyHelperTool/HelperService.swift`: root CA install, trust verification, stale certificate cleanup, and helper service implementation.
- `Shared/CallerValidation.swift`: caller validation through certificate chain comparison.
- `RockxyMCP/`: local MCP bridge exposing captured traffic to AI tools.
- `README.zh.md`: product-level references for traffic capture, SSL proxying, bypass/block rules, map local/remote, breakpoints, throttling, HAR export, redaction, and iOS Device & Simulator positioning.

## TritonKit Mapping

For TritonKit, Rockxy should inform the design of:

- `triton sim proxy start --simulator <udid|booted> --mode record|mock|block --output <dir> --json`
- `triton sim proxy status --simulator <udid|booted> --json`
- `triton sim proxy export --simulator <udid|booted> --output <path.har|path.ndjson> --json`
- `triton sim proxy stop --simulator <udid|booted> --restore --json`

The key takeaway is not to copy Rockxy's UI product surface, but to reuse the engineering lessons around privileged proxy configuration, restore safety, certificate trust state, bypass rules, capture artifacts, redaction, and machine-readable automation surfaces.
