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

`tritonkit-runtime` is not a member of the official TritonKit public bundle. If an adopting project has a separately maintained skill with that name, update it against `triton schema --json` before use. For CLI 0.2.8 and later, legacy action roots such as `find`, `tap`, `type`, `paste`, `clear`, `focus`, `set-text`, and `input` belong under `triton act`; the legacy `ax` and `geometry` roots belong under `triton debug`. Compatibility aliases are intentionally not promised.

Release packaging validates every literal `triton` command root in public Markdown against `docs-linhay/scripts/public-skill-command-schema.json`. The `act` and `debug` subcommand sets are also strict. A CLI hierarchy change must update that snapshot and its CLI contract test before public skills can be packaged.

Repository-maintenance, governance, planning, supervision, and implementation skills live under `.agents/skills/` and must not be packaged into public release skill bundles.
