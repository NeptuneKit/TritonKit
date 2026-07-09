## Safety Rules

- Destructive or state-changing host actions must require explicit flags or policy. Current example: `app uninstall` requires `--confirm` and otherwise returns `destructive_action_requires_policy`.
- Host command success is not business success. After `launch`, `open-url`, `install`, or `uninstall`, verify with `wait`, `find`, `assert`, screenshot, app prefs, layout/AX, or evidence.
- Multiple local targets must return `ambiguous_target` instead of picking an unsafe default.
- Every host action should preserve source command, target, elapsed time, risk/policy metadata when available, and next verification advice.
- Logs, screenshots, layout dumps, and data snapshots must be bounded and redacted when persisted into evidence.
- When a platform has both host-side and embedded runtime observation, keep source boundaries visible. Host layout can prove current visible nodes and coordinates; embedded runtime can prove App-private route, responder, semantic action, WebView controller, and bridge state; WebView/page bridge can prove DOM/JS/page events. Fusion may produce stable `fusedNodeId` values, but must preserve `sources`, `confidence`, `missingSources`, and `candidateOnly` when Web/runtime semantics are absent.
