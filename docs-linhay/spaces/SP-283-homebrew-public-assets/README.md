# SP-283 — Homebrew 更新前公开资产门禁

## 范围与来源

采用 [Loupe 固定增量](https://github.com/heoblitz/Loupe/compare/180c60584867500b93b43ca6c8b556995bf8be7b...1b6c7f0fa5f5ed2bd7885d404f85bcebd5ff0d93) 的发布前公开资产校验顺序。许可全文人工识别 MIT，API NOASSERTION 原样保留；独立实现机制，不复制上游代码。评估见 SP-207 的 20261111 日报与仓外 review。

实际 main `607410fb` 的 tap workflow 只用认证下载 checksum 后渲染并推送；Release workflow 可向已有 draft 上传资产，未在 tap 写入前证明公开可下载。`release.sh` 后置 brew fetch 无法保护这个窗口。

影响层仅发布 workflow、Python 标准库 helper 与离线契约测试。按最新规则在当前 main 串行实施，保留 SP-281 WIP；不运行发布、push、安装或上游代码，不新增 x86_64。

## BDD

- Given draft、prerelease、未公开或 tag 不匹配，When 验证开始，Then 在资产下载和 tap 写入前拒绝。
- Given 公开精确 tag，When 匿名下载 checksum 或 arm64 失败、截断或 hash 不匹配，Then 非零退出，不发布可用 checksum。
- Given 重复目标、非法 hash 或不安全路径，When 解析 manifest，Then 拒绝，不让渲染器选中歧义条目。
- Given 精确公开稳定 tag 与匿名 arm64 字节 SHA 一致，When 验证成功，Then 仅发布已验证 arm64 checksum，后续才渲染/写 tap。
- Given 网络超时或字节预算耗尽，Then 保持失败；不关闭 TLS、不携带 GH_TOKEN、不执行下载内容。

## 验收

状态：已在main提交14574a7b并通过提交后复验；先失败测试，后最小实现。最终证据见 `plans/20261111-validation.md`。离线 fixture 不等于真实 GitHub/跨区域可用性验收；本轮不发布、不推送、不安装。
