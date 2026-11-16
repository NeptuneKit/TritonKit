# TritonKit 内部 skills

按 [AGENTS.md](../../AGENTS.md) 核对项目约束，从 [经验索引](../../docs-linhay/memory/EXPERIENCE.md) 读取命中主题，按 [项目 Agent 治理](../../docs-linhay/dev/20260619-agent-workflow-skill-governance.md) 收尾。

| 任务 | 使用的 skill |
| --- | --- |
| Space、维护资料、经验回写 | [项目治理](tritonkit-ops-governance/SKILL.md) |
| 分派、复核证据、整合交付 | [主控监督](tritonkit-subagent-supervision/SKILL.md) |
| 多个方案需要裁决 | [方案裁决](tritonkit-plan-arbiter/SKILL.md) |
| 用户要求无人值守推进 | [自动巡航](tritonkit-autonomous-cruise/SKILL.md) |
| Android Emulator 或跨平台真机的分派 | [设备任务编排](tritonkit-device-subagent-orchestration/SKILL.md) |
| Apple Simulator 宿主能力，或 Xcode 构建、测试与诊断 | [Simulator 接管](tritonkit-host-simulator-takeover/SKILL.md)、[Xcode 工作流](tritonkit-xcode-workflow-takeover/SKILL.md) |
| 本地 MLX 模型与运行验证 | [本地 MLX VLM](tritonkit-local-mlx-vlm-provider/SKILL.md) |
| Web 设计与组件 | [Web 设计及评审](tritonkit-web-mock-ui/SKILL.md)、[Rhine Design](rhine-design/SKILL.md)、[Ant Design](antd/SKILL.md)（实际用到 antd 时） |
| 发布与制品验收 | [发布治理](tritonkit-release-package-governance/SKILL.md) |

本机模拟器日常操作见[模拟器操作 skill](../../TritonKit.skills/tritonkit-emulator-cli-takeover/SKILL.md)。外部接入、升级和真实项目回归见 [TritonKit.skills](../../TritonKit.skills/README.md)，该目录是发布包的源码入口。
