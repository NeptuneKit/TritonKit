# TritonKit Development Skills

This directory contains TritonKit repository development skills for local agent discovery.

These skills are for maintainers working inside this repository: governance, planning, supervision, implementation workflows, and autonomous cruise routines. They are real skill directories, not symlinks.

Public skills for external users live in `TritonKit.skills/` and are packaged into `tritonkit-skills.tar.gz`.

Current internal orchestration entries include:

- `tritonkit-device-subagent-orchestration`: coordinates device-related Codex subagent tracks such as Android Emulator and cross-platform real-device support.
- `tritonkit-plan-arbiter`: compares competing agent plans and chooses one executable TritonKit direction.
- `tritonkit-web-mock-ui`: guides React / Vite Web mock UI work while keeping CLI / HTTP as the control contract.
