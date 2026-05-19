# GitHub CI Release Artifacts

## 背景

TritonKit 需要把云端验证和发布产物固定下来：使用者不仅要拿到 `triton` CLI，也要拿到项目级 skill 包，尤其是开发阶段反馈工作流 `tritonkit-dev-feedback`。

## Workflow

新增 `.github/workflows/ci.yml`：

1. `push` 到 `main`、`pull_request` 到 `main`、手动 `workflow_dispatch` 时运行。
2. tag `v*` 推送时，在同一 workflow 内创建或复用 GitHub Release，并上传产物。
3. 执行 `swift test`。
4. 执行 `swift build -c release --product triton`。
5. 打包 CLI：
   - `triton-macos-<arch>.tar.gz`
   - `triton-macos-<arch>.zip`
6. 打包 skill：
   - `tritonkit-dev-feedback.tar.gz`
   - `tritonkit-dev-feedback.zip`
7. 所有包先作为 workflow artifact 上传；tag 发布时再作为 GitHub Release asset 上传。

## 产物契约

发布产物必须至少包含：

1. `triton` CLI 可执行文件包。
2. `.agents/skills/tritonkit-dev-feedback` skill 包。

后续新增面向使用者的项目级 skill 时，应同步纳入 CI/release packaging。

## 验证

- 本地运行 `swift test` 通过。
- 本地运行 `swift build -c release --product triton` 通过。
- 使用临时目录复现 CI 打包命令，生成 CLI 与 skill 的 `.tar.gz` / `.zip` 产物。
- 用 Python YAML parser 校验 `.github/workflows/ci.yml` 语法可解析。
