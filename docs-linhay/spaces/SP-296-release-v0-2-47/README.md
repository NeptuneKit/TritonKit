# SP-296 TritonKit v0.2.47 发布

范围为 macOS arm64 CLI、随包 Web/Runner、Homebrew、公开 skills 和 SwiftPM iOS 16+。在干净的发布检出中以远端 main `5a5df3fd` 为基线，应用 #284、#285、本轮验收资料及 #284 依赖的 #224 只读 Web 诊断。首轮干净检出编译发现缺少共享 `probeDiagnostic.reason`，补入既有完整诊断提交后重新验收。现有本地提交保留在原工作区。

- Given 已公开 v0.2.46，When 验证 v0.2.47 的版本清单，Then 旧清单必须失败，更新后 Web manifest/lock 与 tag 对齐。
- Given 两项修复通过 CLI 与本地门禁，When 精确 main CI 完成，Then 创建 v0.2.47 并验证 tag CI、正式资产、Homebrew 及仓库外只读 Web。
- Given 发布包通过针对 #284、#285 的验收，When 回复并关闭对应 issue，Then 回读状态及评论并存档。其余已登记的原现场缺口继续跟踪。

纳入修复见 [SP-294](../SP-294-issue-284-hid-admission-diagnostics/README.md) 和 [SP-295](../SP-295-issue-285-recording-worker-startup/README.md)。发布与复验回执将追加在本页。


## 2026-11-26 发布与验收

[v0.2.47](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.47) 已发布，tag 指向 `3cc38e49cd0b52c009bc22ec91bc632e84b4b13e`。[主线 CI](https://github.com/NeptuneKit/TritonKit/actions/runs/45569360556)、[标签 CI](https://github.com/NeptuneKit/TritonKit/actions/runs/45659923031)、[Release 与 tap](https://github.com/NeptuneKit/TritonKit/actions/runs/45659923030) 均通过。

- 本地完整 CLI Swift Testing 1907 项、XCTest 167 项，Web 174 项，版本、文档、skills 和本地总门禁通过。可选 Simulator Xcode 构建跳过，真实 Simulator 行为通过单独命令验证。
- 正式制品包含 arm64 CLI、Web、unsigned Runner、四个 public skills 与 checksum。重新下载后核对大小、SHA-256、归档完整性、Mach-O、CLI 版本与 skills/Runner 版本。SwiftPM 消费同一个 iOS 16+ Git tag。Homebrew tap `635e6692fd0b`，v0.2.46 到 v0.2.47 升级与 `brew test` 通过，安装后二进制与发布包哈希相同。
- Homebrew 发布 CI 通过匿名资产门禁。本机另跑匿名元数据查询遇到 API 403 限流，独立下载按公开制品 checksum 校验通过。两项证据分别记录。
- 仓库外 packaged Web HTML/JS/CSS 成功，完整输入 DTO 返回 `405/web_host_input_readonly`。真实浏览器默认页渲染，选定本轮 iPhone 预览后帧解码成功，观察窗口内 HTTP 和 console 错误为零。最终停止本轮服务与自有 Simulator。
- #284。v0.2.46 在自有 iPhone 17/iOS 27.0 上重现初始拒绝及随后的 `display.state=primary`。本地候选重启后失败回执为 `hid-pre-dispatch / ownership-changed`，正式包另一新启动回执为 `hid-screen-enumeration / portrait-required`，均在接触前拒绝。两个回执各自归属对应尝试；不能据此追溯报告中的历史尝试。doctor 的当前预检明确保留 `inputDispatchVerified=false`。[回复并关闭](https://github.com/NeptuneKit/TritonKit/issues/284#issuecomment-7169322982)
- #285。正式 CLI 在自有 iPhone 上回收旧 PATH 调用留下的无主会话并复用同一输出名；PATH 与绝对路径均完成并完整解码 MP4。静止首页两次只有约 0.067 秒有效视频样本，此处验证启动和恢复。[回复并关闭](https://github.com/NeptuneKit/TritonKit/issues/285#issuecomment-7169319452)

其他五项逐条回复，保留原环境验收缺口。 [#224](https://github.com/NeptuneKit/TritonKit/issues/224#issuecomment-7169333500) · [#237](https://github.com/NeptuneKit/TritonKit/issues/237#issuecomment-7169331306) · [#238](https://github.com/NeptuneKit/TritonKit/issues/238#issuecomment-7169329376) · [#246](https://github.com/NeptuneKit/TritonKit/issues/246#issuecomment-7169327499) · [#274](https://github.com/NeptuneKit/TritonKit/issues/274#issuecomment-7169325827)。
