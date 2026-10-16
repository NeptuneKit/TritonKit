# 用户回复草稿（未发送）

已确认是我们更新检查的缺陷：旧版Homebrew检查未查询最新版，也可能误报“无更新”；CLI与skills又是独立更新，导致版本差异。

修复已发布到[v0.2.30](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.30)，已验证双架构CLI、Homebrew与skills版本一致。请先更新旧CLI：

```sh
brew update
brew upgrade neptunekit/tap/triton
triton version --json
triton update --check --json
```

确认CLI为0.2.30或更高的目标发布版后，按实际agent安装目录逐一更新skills：

```sh
triton update --include-skills --skills-dir ~/.codex/skills --yes --json
triton update --include-skills --skills-dir ~/.agents/skills --yes --json
```

只执行实际使用的目录。新版会检查CLI实际安装版本与skills元数据；如本地skills有修改，保留冲突内容按提示处理。若仍有差异，请提供version/check的JSON结果，我们继续定位。维护机验证不代表你的机器已完成升级。

发送渠道尚未指定，本草稿未外发。
