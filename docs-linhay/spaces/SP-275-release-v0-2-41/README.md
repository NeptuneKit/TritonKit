# SP-275 — v0.2.41 发布

## 边界

发布包含 PR #278 合并后的 #277 Host input 门控修复。版本 surfaces 必须对齐：CLI、嵌入 Web、公开 skills、双架构 checksum、Homebrew、TritonKit.podspec 与 Web manifests。

真实 Simulator tap/capture、iPad 默认截图/HID、原私有 App 和人工 IME 仍按主流程范围外或未知记录，不以本版本发布替代这些验收。

## BDD

- Given v0.2.40 已发布且 tag 不可移动，When 0.2.41 版本文件与完整 preflight 通过，Then 创建新的不可移动 v0.2.41 tag。
- Given #277 精确修复已在 main 且 main CI 通过，When Release 资产、skills、Homebrew、packaged Web 与安装版复验，Then 所有公开包 surfaces 使用同一版本与 SHA。
- CocoaPods 仅执行标准 lint，是否推 trunk 单独报告。

## 验收记录

- 版本预检：旧 manifests 对 0.2.41 按治理要求失败；升级后需重新验证。
- #277 focused/full CLI、PR CI 与合并后 main CI 已通过。
- 发布前版本、自动化、docs、skills 与 Web build 通过；标准本机 Pod lint 受 Xcode 27.1/iOS 13 工具链边界阻断，兼容 iOS 15 lint 输出 `TritonKit passed validation.`，远端标准 Pod 仍为必需门禁。
- 发布后补充 tag、资产 checksum、安装与 Web smoke 证据；不得宣称真实私有 App 恢复。
