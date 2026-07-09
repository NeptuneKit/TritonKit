## Boundaries

- Do not commit or revert real app repo changes unless the user explicitly asks.
- Do not publish real app identity, private bundle IDs, personal accounts, user names, emails, internal hosts, absolute private paths, or unredacted evidence in TritonKit issues.
- Inspect evidence manifests, screenshot pixels, and artifact filenames before attaching them to public issues. If redaction cannot be verified, summarize the evidence instead.
- Do not treat a successful tap as completion; verify the resulting app state.
- Do not add Web/Wails UI to satisfy real-project needs when CLI/HTTP can provide the contract.
- System alerts and SpringBoard-level controls remain outside embedded runtime scope; expect `runtime_ui_interrupted` or unsupported errors.
- If the requirement becomes product work, create or update the corresponding `space` before implementation.
