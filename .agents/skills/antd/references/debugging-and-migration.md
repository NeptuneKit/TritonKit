# Debugging And Migration

Use this reference when diagnosing AntD issues, upgrading versions, checking changelogs, or analyzing project usage.

## Debugging

```bash
antd env --format json
antd doctor --format json
antd info Select --version 5.12.0 --format json
antd lint ./src/components/MyForm.tsx --format json
```

Workflow:

1. `antd env` for environment.
2. `antd doctor` for configuration.
3. `antd info --version X` for exact API.
4. `antd lint` for deprecated or invalid usage.

## Migration

```bash
antd migrate 3 4 --format json
antd migrate 4 5 --format json
antd migrate 5 6 --format json
antd migrate 4 5 --component Select --format json
antd migrate 4 5 --apply ./src --format json
antd changelog 4.24.0 5.0.0 --format json
antd changelog 4.24.0 5.0.0 Select --format json
```

Workflow:

1. `antd migrate` for checklist.
2. `antd changelog` for breaking changes.
3. Apply fixes.
4. `antd lint` to verify.

## Changelog

```bash
antd changelog 5.22.0 --format json
antd changelog 5.21.0..5.24.0 --format json
```
