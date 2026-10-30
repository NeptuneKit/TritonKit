# 2026-10-30 并行 Space 登记前置

Decision: Adopt 最小真实登记。四个既有Space尚未提交，独立issue的连续编号门禁不能靠混入其产品WIP或放宽校验解决。仅保存真实需求/BDD/归属/来源摘要；原资料与工作区不修改。SP-247主索引已用于Rhine偏好，本轮未提交的#237候选移至SP-249；#238保留SP-248。原本地HEAD30185dc2的历史日检文档不随本次远端交付。

编号分配须联合读取主索引和全部注册worktree/分支的已占编号；主目录尚未合入的独立分支同样占号。碰号只调整本轮未提交候选，不重编号别人已登记Space。

采样来源（仅摘要，不表示产品已合入main）：

```json
[
  {
    "key": "SP-244-emulator-service-slimming",
    "source": "main working tree docs-linhay/spaces/SP-244-emulator-service-slimming/README.md",
    "sha256": "f87815c173c5462db7a689de60eecb09d8b08093ec5bbe8700a9577c71196d6f"
  },
  {
    "key": "SP-245-rhine-design-adoption",
    "source": "main working tree docs-linhay/spaces/SP-245-rhine-design-adoption/README.md",
    "sha256": "d58a471b7de98397c009f0a967af3eaca80af13e296ec7222f57ec337d949c03"
  },
  {
    "key": "SP-246-rhine-web-migration",
    "source": "main working tree docs-linhay/spaces/SP-246-rhine-web-migration/README.md",
    "sha256": "85eaad6b470adb15066bb80b0a2b7d93eda6f882174da37e4c9f0a4873fe3d77"
  },
  {
    "key": "SP-247-rhine-page-preferences",
    "source": "main working tree docs-linhay/spaces/SP-247-rhine-page-preferences/README.md",
    "sha256": "8783953e76c5de28f1a18b89f9d715fd22d2ae7dff76196c917c7f50cffafd3f"
  }
]
```

验收使用原有docs门禁，并独立核对前置提交仅包含四份登记README、两索引、本说明及必要治理修正，不包含其他产品代码或设计稿。
