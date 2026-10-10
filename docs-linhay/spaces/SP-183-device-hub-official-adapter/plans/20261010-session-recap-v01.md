# SP-183 会话沉淀与后续分批计划

## 本次提交边界

用户明确要求“整理，沉淀，提交”。本次仅在 `feat/SP-183-device-hub-official-adapter` 本地提交本任务实现、测试、schema、文档及脱敏验收摘要；不合并、不推送、不发布、不替换安装 CLI。主仓 SP-181/182 的研究、共享索引与混合每日记忆保持未提交，不通过复制、stash、reset 或伪造空间消除隔离基线缺号。此提交不是完整 Device Hub 集成完成声明。

原始 SDK JSON、设备身份/别名、日志、图片、私有诊断路径及构建产物仍保留于被忽略的 references/build 目录，不进入提交。历史段落的“未提交”属于当时验收快照；本节记录新增提交授权，不覆盖历史证据。

## 已实现与证据分层

| 能力组 | 当前接入 | 不能据此声称 |
|---|---|---|
| 新旧设备发现与分发 | 新 properties 权威、旧布局保留、sim 身份归并、scope 隔离、private aliases | 所有 Apple 平台/业务 ready，或旧 SDK 实机验收 |
| Simulator | 旧 sim/app/xcode 单点入口保留；owned 生命周期/rename、每阶段 timeout 传递已验 | 截图黑屏等于业务成功，或借用业务设备扩大验收 |
| 只读设备信息与文件 | info/lock-state、浅 metadata files、mountpoint；已有各片实际证据 | screenLocked、文件内容、挂载真实性、动作授权 |
| DeviceFS | 三固定 namespace、显式原生容器、受限相对子目录与同 FD 安全检查 | bundle/group 语义归属、Crash 映射、Temporary 创建政策 |
| 真机管理 | pair/unpair/diagnose 独立 plan-only，SDK flags/help 与隐私保护 | 原生操作执行、配对状态、压缩包安全或诊断范围已接受 |
| 平台与硬件 | 六 family 静态目录、可选 available Simulator 聚合；info 显式硬件观察 | 仅由目录/capability 名称/runtime/设备名推断专门控制或 iPadOS |

最新代码回归：CLI **1104 Swift Testing/95 suites +14 XCTest**、根包 **303 Swift Testing +7 XCTest**通过；Release通过。当前 SDK 的 fresh identity-bound readonly info 返回 ios/iphone/physical、modern source，仍不是业务/硬件真实性或全 family live 接受。细节见[硬件来源 ledger](<./20261010-hardware-observation-verification.json>)、[平台报告 ledger](<./20261010-apple-platform-verification.json>)、[管理计划 ledger](<./20261010-device-administration-verification.json>)及[全能力矩阵](<./20261009-full-capability-matrix.md>)。

本地产品子门禁通过；通用 Simulator 工程构建是显式 skip，不算 iOS UIKit live 测试。隔离 docs-ci/check-docs 仅剩既有 SP181/182 编号连续性缺口；主仓两门禁通过，183 spaces。自建非可追溯日志名触发门禁时，只在精确 absolute 源/目标验证后改名保留记录，不放宽 checker。

## 可复用规则（项目 skills，不上升为 AGENTS）

1. **稳定单点契约**：Apple 工具是 backend resource；保留旧 namespace/IDs/argv，新的能力不依赖 mandatory server、Run 或 WorkflowEngine。按 capability group 批量推进，BDD/TDD 与契约一致后集中回归，避免仅补报告而无执行能力。
2. **证据不能跨层替代**：help-advertised、合成 fixture、source review/DI、实际 CLI envelope、动作及业务后置条件分别记录。没有真实新 SDK/旧 SDK/动作证据就写未验；不可使用不可拦截的 PATH wrapper 伪称 trace。
3. **权威字段与 unknown**：modern present/null/partial 不复活 deprecated mirror；显式 metadata 和兼容分发假设分开。名称、product、marketing、runtime 和 capabilities 不启用动作、不证明 OS/physical/readiness。
4. **隐私覆盖所有异常路径**：保留稳定 error code，用静态 message/hint；不得透传 discovery 的原始 candidates、SDK logs 或路径。诊断 refs 本机使用，发布前脱敏；不要把关闭 host sysdiagnose 称为排除了 host CoreDevice logs。
5. **DeviceFS authority 是 bytes + FD**：精确根/UUID/UTF8 身份、逐组件 nofollow、root 与每层 owner、同 FD 双 stat、Darwin variable dirent 边界；仅 exact devicefs 允许已观察的合成 inode 差异。相对路径不 normalize/URL-decode，预算先 preflight、绑定实际 root 后复验。
6. **门禁与源隔离**：同 scratch 的 test/build/设备操作串行；显式本次 TRITON_CLI_PATH；fixtures 初始化所有 ArgumentParser 属性。只 stage 本任务 manifest，不带 raw references、build、锁文件/生成文件或 unrelated space，主仓 mirror 留待独立集成裁决。

这些规则已沉淀到现有内部 host-simulator/xcode skill 和 public emulator/regression/feedback skill；不新增 skill，不修改 repo-wide AGENTS。

## 下一阶段四批交付

1. **容器与文件域**：先核实官方/versioned App metadata→native container 的 bundle/group 绑定，再补 Crash 与 Temporary。原生目录名不能冒充语义归属；Temporary 若创建域，必须显式政策/审计，禁止 readonly 伪装。当前授权不扩展到业务内容读取或真机写。
2. **管理执行 backend**：从现有 plan-only 补 objective 配置、授权/审计、native fileJSON 绑定、失败/超时/部分完成与 postconditions；diagnose archive 需内容范围、private 权限、nooverwrite/nofollow/size 验证。可以先实现隔离/注入测试，真实物理执行仍需单独授权，不虚构 action result shape。
3. **专门平台能力**：非 iOS physical 发现/selection/per-family provenance，加 watch Crown/侧键、tv 焦点、vision 视角/输入/场景、mac Device Hub 与 Xcode workflow 边界。依据真实公开 backend 接入；GUI-only 或无可验证公开接口明确列缺口，不私造实现或自动 capability-enable。
4. **全矩阵收口**：新旧布局及旧 argv 全回归、owned Simulator 可逆 live、SDK版本/平台/动作/业务证据逐项核对；保持 docs/skills/schema/memory 一致。只有全目标证据成立才 complete；合并、推送、发布另行授权。
