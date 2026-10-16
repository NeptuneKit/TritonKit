# 用户回复草稿（未发送）

已确认是 Triton 更新检查的缺陷：旧版在 Homebrew 安装场景下未查询最新版，也可能返回“无更新”。CLI 和 skills 又是独立更新，因此你反馈的版本差异有效。

我们正在修复检查误报、升级后的实际版本核验，以及 CLI/skills 同版本校验。修复版发布并完成安装验证后，会提供准确版本与升级步骤；目前不会把维护机已更新作为你的环境已修复的依据。

旧版临时处理：先核对 GitHub 最新 Release 与远端 Homebrew formula。通过 `brew update`、`brew upgrade neptunekit/tap/triton` 更新 CLI，再执行 `triton version --json` 核对实际版本。只有 CLI 版本与目标 release 一致时，再按更新 skill 的 guarded installer 流程更新 skills；保留本地修改和备份，逐个核对已安装 bundle 的 BUILD_INFO。不能只凭旧 `updateAvailable=false` 或 `updated=true` 判断完成。

发布后发送前需填入已验证版本、Release 链接及确认过的用户通知渠道；当前草稿不宣称已发布。
