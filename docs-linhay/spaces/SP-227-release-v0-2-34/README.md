# SP-227 v0.2.34 发布

## 边界

将当前本地 `main` 的已验收内容发布为 `v0.2.34`。范围覆盖 CLI 双架构资产、内置 Web、公开 skills bundle、iOS `TritonKit.podspec`、Web package manifests、Homebrew tap 与 GitHub Release。SwiftPM 通过 Git tag 解析版本；CocoaPods 只执行 lint，不推送 trunk。

## BDD 与验收

1. Given `v0.2.33` 已发布且 `main` 包含后续已验收合并，When 选择下一补丁版本，Then 只创建新的不可移动 `v0.2.34` tag。
2. Given 三份公开版本清单，When 运行版本契约校验，Then `TritonKit.podspec`、`Web/package.json` 与 `Web/package-lock.json` 均为 `0.2.34`。
3. Given 发布工作流，When tag 触发 CI/Release，Then arm64 先行、x86_64 回填、skills checksum、Homebrew tap 与公开 Release 资产均成功。
4. Given 发布后安装入口，When 读取 CLI 版本、packaged Web 与 skills 元数据，Then 均报告 `0.2.34`；只读 Web smoke 保持现有契约。

## 验收边界

- 本地门禁、Web build、skills package、Podspec lint 与发布契约均需记录实际退出码和关键输出。
- 真实用户工程、真机、设备签名、CocoaPods trunk 推送不属于本次自动发布范围。
- 发布脚本会推送 `main` 与 `v0.2.34`；旧 tag 不移动。

## 状态

准备中。发布前证据写入 `plans/20261027-v0.2.34-release.md`；发布完成后补充 GitHub Actions、资产、Homebrew、安装与仓库外 Web smoke 结果。
