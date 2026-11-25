# SP-296 TritonKit v0.2.47 发布

范围为 macOS arm64 CLI、随包 Web/Runner、Homebrew、公开 skills 和 SwiftPM iOS 16+。在干净的发布检出中以远端 main `5a5df3fd` 为基线，只应用 #284、#285 与本轮验收资料。现有本地提交保留在原工作区。

- Given 已公开 v0.2.46，When 验证 v0.2.47 的版本清单，Then 旧清单必须失败，更新后 Web manifest/lock 与 tag 对齐。
- Given 两项修复通过 CLI 与本地门禁，When 精确 main CI 完成，Then 创建 v0.2.47 并验证 tag CI、正式资产、Homebrew 及仓库外只读 Web。
- Given 发布包通过针对 #284、#285 的验收，When 回复并关闭对应 issue，Then 回读状态及评论并存档。其余已登记的原现场缺口继续跟踪。

纳入修复见 [SP-294](../SP-294-issue-284-hid-admission-diagnostics/README.md) 和 [SP-295](../SP-295-issue-285-recording-worker-startup/README.md)。发布与复验回执将追加在本页。
