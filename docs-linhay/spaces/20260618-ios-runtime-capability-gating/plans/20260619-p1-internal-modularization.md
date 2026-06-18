# 2026-06-19 P1 Internal Modularization

## Scope

Keep the public SwiftPM and CocoaPods surface unchanged. This slice only extracts the runtime capability gate from `TritonKitRequestHandler` into a dedicated internal module so future Observe / Input / WebView / Semantic handler splits can share one capability decision point.

## BDD Scenarios

### Scenario 1: Capability mapping is testable outside the handler

Given a runtime request message
When the capability gate maps it to a runtime capability
Then the mapping is available without executing `TritonKitRequestHandler`.

### Scenario 2: Disabled response shape stays stable after extraction

Given a runtime configuration with WebView or input disabled
When the capability gate builds the disabled response
Then the response keeps the same model-specific JSON shape and `error.code=capability_disabled`.

## Implementation Plan

1. Add focused tests for request type to capability/action mapping and disabled response JSON shape.
2. Add `TKRuntimeCapabilityGate.swift` for capability mapping, action names, and disabled response construction.
3. Move `TritonKit.Configuration.isRuntimeCapabilityEnabled` into the same capability module.
4. Reduce `TritonKitRequestHandler` back to routing and concrete handlers.

## Test Plan

- `swift test --filter TKPlatformFallbackTests`
- `swift test`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`

# 2026-06-19 P2 Handler Domain Split

## Scope

Keep the public `TritonKit` product, runtime manifest, and request/response payloads unchanged. This slice reduces `TritonKitRequestHandler` to runtime guard, capability gate, ledger recording, and domain routing, then moves concrete Observe / Input / WebView / Semantic / legacy inspection handlers into focused extension files.

## BDD Scenarios

### Scenario 1: Request domains are explicit and testable

Given a runtime request type
When the request is routed
Then it maps to a stable internal domain without executing the handler body.

### Scenario 2: Domain split preserves response contracts

Given existing input, WebView, semantic, and observe requests
When their implementations move to domain extension files
Then the JSON response shape and error codes remain unchanged.

## Implementation Plan

1. Add a focused test for request type to handler domain mapping.
2. Add `TKRuntimeRequestDomain.swift` as the internal routing boundary.
3. Split concrete handler bodies into `TritonKitRequestHandler+Observation.swift`, `+Input.swift`, `+WebView.swift`, `+Semantic.swift`, and `+LegacyInspection.swift`.
4. Keep `TritonKitRequestHandler.swift` as the top-level router and ledger owner.

## Test Plan

- `swift test --filter TKPlatformFallbackTests`
- `swift test`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
