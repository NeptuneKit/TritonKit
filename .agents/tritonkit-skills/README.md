# TritonKit Skills

This directory is the canonical source for TritonKit-owned skills.

## Layout

- `public/`: skills packaged into `tritonkit-skills.tar.gz` and intended for external TritonKit users or adopting projects.
- `internal/`: repo-maintenance, governance, planning, supervision, and implementation skills for TritonKit maintainers. These must not be published in release skill bundles.
- `.agents/skills/`: local discovery shims. Entries there are symlinks back to this directory so local agents can still discover project skills without making `.agents/skills` the packaging source.

## Packaging Contract

Release automation packages only `public/`:

- `tritonkit-dev-feedback`
- `tritonkit-emulator-cli-takeover`
- `tritonkit-real-project-regression`

Internal skills may reference public skills, but public skills should avoid depending on internal repo-maintenance workflows.
