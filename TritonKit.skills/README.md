# TritonKit Public Skills

This directory is the canonical source and install bundle for TritonKit skills distributed to external users and adopting projects.

Install this directory itself into the configured Codex / agent skills directory:

```sh
cp -R TritonKit.skills "$AGENT_SKILLS_DIR"/TritonKit.skills
```

If upgrading from the old layout, delete these old top-level directories from the agent skills directory before installing `TritonKit.skills/`:

- `tritonkit-dev-feedback`
- `tritonkit-emulator-cli-takeover`
- `tritonkit-real-project-regression`
- `tritonkit-update`

Release automation packages this directory into `tritonkit-skills.tar.gz`; extracting that asset into the agent skills directory creates `TritonKit.skills/`.

The bundle contains:

- `tritonkit-dev-feedback`
- `tritonkit-emulator-cli-takeover`
- `tritonkit-real-project-regression`
- `tritonkit-update`

Repository-maintenance, governance, planning, supervision, and implementation skills live under `.agents/skills/` and must not be packaged into public release skill bundles.
