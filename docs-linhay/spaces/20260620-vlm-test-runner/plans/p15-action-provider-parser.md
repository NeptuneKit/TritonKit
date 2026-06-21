# P15 Action Provider Parser

## Goal

Add an offline action-provider parser so external GUI agents can hand TritonKit a single proposed action and receive a bounded Triton primitive preview.

## Scope

- Add `triton action parse --provider <ui-tars|agentcpm-gui> --input <raw> --json`.
- Parse UI-TARS Thought/Action text:
  - `click(start_box='(x,y)')` -> `tap`
  - `swipe(start_box='(x,y)', end_box='(x,y)')` -> `swipe`
  - `type(content='...')` -> `type`
  - `press(key='...')` -> `press`
  - `wait()` -> `wait`
  - `finished/status/done` -> `status`
- Parse AgentCPM-GUI JSON:
  - `POINT/CLICK/TAP` -> `tap`
  - `SWIPE` -> `swipe`
  - `TYPE` -> `type`
  - `PRESS` -> `press`
  - `WAIT` -> `wait`
  - `STATUS/DONE` -> `status`
- Preserve `coordinateSystem=normalized_0_1000` for point actions.
- Return `commandPreview` only; no device operation is executed.

## Out of Scope

- Calling a model.
- Executing parsed actions.
- Multi-step loops.
- Planning or autonomous exploration.
- Selector healing.
- Coordinate transform against a real screenshot.

## Validation

- `swift test --package-path CLI --filter ActionProviderParserTests --filter SchemaFactSourceWorkflowTests`
- `CLI/.build/debug/triton action parse --provider ui-tars --input "Action: click(start_box='(500,330)')" --json`
- `CLI/.build/debug/triton action parse --provider agentcpm-gui --input '{"action":"TYPE","text":"hello"}' --json`

Result: targeted parser/schema tests passed, and both CLI smoke commands returned `triton.action-provider.parse-result`.
