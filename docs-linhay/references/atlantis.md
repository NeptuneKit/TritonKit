# Atlantis Reference

## Source

- Repository: `https://github.com/ProxymanApp/atlantis.git`
- Local snapshot: `docs-linhay/references/atlantis/`
- Snapshot commit: `6427600ec87d516a43754e4eaa7762f3271ac77f`
- Primary README: `docs-linhay/references/atlantis/README.md`
- Local note: example project directories with spaces are locally renamed to no-space slugs so the snapshot satisfies TritonKit docs path rules.

## Why It Matters

Atlantis is an App-embedded traffic capture SDK from the Proxyman team. It is useful as a reference for an application-internal traffic takeover model: the App integrates a package, starts Atlantis in DEBUG or another explicit environment, swizzles selected networking APIs, captures request/response/WebSocket data, and streams structured packages to a macOS collector.

This is a different lane from TritonKit's host-side iOS Simulator proxy takeover. TritonKit's current simulator-network product boundary remains host-side `triton sim proxy ...`; Atlantis is archived here to study the App-internal alternative and its tradeoffs.

## Useful Reference Areas

- `Sources/Atlantis.swift`: public `Atlantis.start(...)`, safety checks, transport bootstrap, delegate hook, ignore protocol list, and manual traffic entry points.
- `Sources/NetworkInjector.swift`: injector contract and URLSession/WebSocket capture surface.
- `Sources/NetworkInjector+URLSession.swift`: method swizzling for `resume`, response, data, completion, upload, and WebSocket callbacks.
- `Sources/Transporter.swift`: Bonjour discovery for devices, simulator direct TCP connection, gzip compression, package framing, retry/pending queue behavior, and local-network transport constraints.
- `Sources/Message.swift` and `Sources/Packages.swift`: request/response/package wire models.
- `Sources/Atlantis+Manual.swift`: manual add APIs for traffic that does not flow through URLSession.
- `README.md`: integration requirements, Info.plist local network / Bonjour keys, DEBUG examples, WebSocket limits, gRPC interceptor pattern, and production/debugging notes.

## TritonKit Mapping

For TritonKit, Atlantis can inform future App-internal network observation only if a new space explicitly chooses that lane. Potential lessons:

- Explicit bootstrap in the business App, guarded by DEBUG or a clear opt-in policy.
- Machine-readable request/response package model, with redaction and bounded body handling before export.
- Transport separation between capture and collector, including queue limits and failure behavior.
- Capability reporting for partial support: URLSession works, third-party socket stacks may not, WebSocket support depends on API usage, and gRPC needs explicit interceptor wiring.
- Manual traffic add APIs for non-URLSession clients, but only when the business App opts in.

Do not use Atlantis as justification to silently add App-side network hooks to TritonKit's current iOS Simulator proxy plan. The default simulator plan remains host-side proxy configuration and evidence capture.
