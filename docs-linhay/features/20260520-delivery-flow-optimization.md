# Delivery Flow Optimization

## 背景

Issue #8 收尾时，代码和本地验证已经完成，但交付闭环仍卡在串行等待和人工命令错误上：普通 `main` push 等待完整 CLI release artifact 链，`gh run watch` 重复输出过多，GitHub issue 评论直接传 shell 字符串导致反引号被执行，通用 check 脚本也无法识别本仓库 SwiftPM 门禁。

## 目标

- 普通 push / PR 只阻塞在必要 validate 门禁，不等待 release 打包。
- tag release 或手动触发时仍然产出 CLI 和 skill 包。
- 本地和 CI 共享一个项目级验证入口。
- GitHub issue 评论默认通过文件传递 Markdown，避免 shell 命令替换。
- CI 观察输出保持低噪音，失败时再进入详细日志。
- 文档门禁入口项目化，并明确当前 历史检索维护命令仍是全量 collection。

## BDD 场景

### 场景一：普通 main push 快速反馈

- Given 开发者 push 到 `main`
- When GitHub CI 被触发
- Then 必须运行 Swift 测试、CocoaPods spec、Homebrew formula template 和版本脚本校验
- And 不应阻塞等待 arm64/x86_64 CLI artifact 与 release asset 打包

### 场景二：release tag 仍产出发布物

- Given 推送 `v*` tag
- When GitHub CI 被触发
- Then 必须运行 validate、双架构 CLI build、skill artifact 打包、checksum 和 release asset 校验
- And Homebrew tap 更新仍只在 tag release 后执行

### 场景三：Issue 评论不执行 Markdown 内容

- Given 评论内容包含反引号命令片段
- When 使用项目脚本提交评论
- Then `gh` 必须通过 `--body-file` 读取正文
- And shell 不应执行正文里的反引号内容

### 场景四：CI 观察低噪音

- Given 一个 GitHub Actions run id
- When 使用项目脚本观察 run
- Then 输出每个 job 的简短状态、结论和 URL
- And run 完成后按结论返回退出码

## 非目标

- 不改 历史检索工具；当前 文档结构检查 仍会维护所有已配置 collection。
- 不移除 release artifact 能力；只调整触发条件。
