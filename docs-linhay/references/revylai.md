# RevylAI Reference

## 来源

- GitHub organization: `https://github.com/RevylAI`
- 本地源码参考：`docs-linhay/references/revyl-cli/`
- Source repo: `https://github.com/RevylAI/revyl-cli`
- Clone HEAD: `9931a77`
- Issue: `https://github.com/NeptuneKit/TritonKit/issues/24`
- 调研日期：2026-05-24
- 源码克隆日期：2026-05-27

## 项目定位

RevylAI 的公开定位是移动 App 的主动可靠性测试平台：通过 CLI、云设备、AI agent、截图证据和报告，在用户遇到问题前发现 bug。

公开仓库呈现的是一个组合产品矩阵：

| 仓库 | 定位 | 对 TritonKit 的参考价值 |
| --- | --- | --- |
| `RevylAI/revyl-cli` | 主 CLI，覆盖云设备、build upload、test/workflow、dev loop、agent skills | CLI onboarding、skill installer、workflow/test 命令族、报告链接与 CI 入口 |
| `RevylAI/app-explorer` | AI BFS 探索移动 App，生成 screen map、screenshots、journey viewer | `triton explore/map`、静态 screen skeleton、runtime BFS、screen graph artifact |
| `RevylAI/greenlight` | App Store 提交前离线 compliance scanner | `triton preflight` / `doctor` 的本地静态检查、JSON 输出、AI 修复循环 |
| `RevylAI/mobile-devtools` | PR review、visual regression、Figma checker、security scanner 的工具集入口 | 以可复用模板组织 mobile engineering workflows |
| `RevylAI/mobile-pr-reviewer` | Claude 读 PR diff、启动云设备、探索变更页面、贴 recording/comment | CI PR evidence comment、diff-aware smoke selection |
| `RevylAI/visual-regression` | 两个 build 的截图采集、pixel diff、HTML/Markdown report、threshold gate | 本地 screenshot baseline/current/diff artifact、状态栏 mask、PR gate |
| `RevylAI/figma-design-checker` | Figma frame 与真实 App screenshot 做 pixel diff 和评分 | 设计稿对齐检查可作为未来独立 space，不进入当前 emulator core |
| `RevylAI/CogniSim` | 面向 LLM agent 的 iOS/Android interaction adapter，结合 AX tree 与 set-of-mark | 状态压缩、AX + mark prompting、driver 抽象的参考，不采用 Appium 依赖 |

## 核心模式

### 1. CLI 是 agent 和 CI 的主入口

RevylAI 公开材料把 CLI 放在产品入口中心：`doctor`、`init`、`build upload`、`dev`、`test run`、`workflow run`、`skill install` 形成一条从本地项目到云设备验证的链路。

TritonKit 已坚持 CLI/JSON/JSONL-first，这一方向应继续保持。可吸收的是 CLI onboarding 的完整性：

- `triton doctor` 不只检查 server/runtime，也检查 Xcode、simulator、HDC、Homebrew 安装、版本和常见权限。
- `triton schema` 与 public skills 之外，后续可考虑 `triton skill list/install/export`，让外部 agent 不需要手动复制 `.agents/tritonkit-skills/public/`。
- `triton workflow` / `.tritonplan` 需要保持可读、可验证、可复跑，而不是只做一次性命令拼接。

### 2. Agent skill 是产品能力的一部分

RevylAI CLI 明确暴露 `skill install/show/export`，并按意图拆分 dev loop、test creation、auth bypass 等 skill。

TritonKit 已有 public skills 包，后续可以补齐两个缺口：

1. skill 安装和版本检查的 CLI 入口。
2. 每个 public skill 都能指向稳定的 Triton command schema 和最小可复跑示例。

这不要求新增 Web，也不要求云服务；它只是让 agent 入口更可发现。

### 3. Screen graph 是 evidence 之外的独立产物

`app-explorer` 把一次探索产物拆成 screen inventory、transitions、screenshots、user paths 和 interactive viewer。它还先做 iOS static skeleton，再让 agent BFS 补 runtime edges。

对 TritonKit 的直接启发：

- `.tritonevidence` 适合证明一次 case 是否通过；`screen-map.json` 适合描述 App 可达空间。
- 后续可新增独立 space：`triton explore` 或 `triton map`，产物包括 `screens.json`、`transitions.jsonl`、`screenshots/` 和 `report.md`。
- iOS static skeleton 可以作为可选加速器，先从 bundle class/type/string table 中提取候选 screen，不替代 runtime BFS。
- 运行时 BFS 必须继续用 `wait/assert/screenshot/evidence` 证明状态，不把“探索过”当作业务通过。

### 4. Visual regression 和 design diff 是 artifact workflow

`visual-regression` 和 `figma-design-checker` 都把截图采集、像素 diff、HTML/Markdown report、threshold gate 做成独立 workflow。重要细节是：状态栏等动态区域要 mask，报告要能放进 PR。

TritonKit 可吸收为后续 artifact 能力：

- `triton screenshot compare --baseline <png> --current <png> --output <dir> --json`
- `triton capture --case <case> --include screenshot` 后可生成 baseline/current/diff 三件套。
- diff 结果只证明视觉变化，不证明业务正确；仍需 runtime assert 或 smoke summary。

当前不应把它并入 emulator takeover P0/P1，适合等 screenshot/evidence 更稳定后单独建 space。

### 5. PR review bot 强调“变更驱动的最小验证”

`mobile-pr-reviewer` 的公开 README 强调 Claude 读取 diff、定位可能受影响的 screen、启动设备、操作并贴 recording/comment。这个模式对 TritonKit 的真实项目回归有价值，但要改成本机 CLI 版本：

- 输入：PR diff、已知 route/screen hints、构建产物。
- 执行：`triton xcode run` / `triton smoke ios` / `triton capture`。
- 输出：Markdown comment，包含 pass/fail、artifact path、screenshot、建议复现命令。

短期可先沉淀为 GitHub Action 模板或 docs，不需要产品内置 CI bot。

### 6. Offline preflight 值得单独借鉴

`greenlight` 的强点不是设备控制，而是“一命令、离线、JSON、可被 agent 修复循环消费”的 preflight 模式。TritonKit 可在两个方向借鉴：

- 对使用者 App：检查 DEBUG bootstrap、Release no-op、SwiftPM/CocoaPods 集成、URL scheme、runtime 启动位置。
- 对 TritonKit 仓库：检查 release asset、Homebrew formula、public skill package、schema 示例是否一致。

这类能力应叫 `triton preflight` 或继续扩展 `doctor`，不应该和 runtime action 命令混在一起。

### 7. AX + screenshot 状态压缩

`CogniSim` 明确提到只发 accessibility tree 太长、只发 screenshot 又不够准确，因此结合 AX tree 和 set-of-mark 提供可读 state。

TritonKit 当前已有 AX、geometry、screenshot 和 candidates。后续可以吸收：

- 为 agent 提供压缩 state：visible text、interactive candidates、bounds、role、screenshot reference。
- overlay/mark 只能作为 agent debug artifact，主截图证据默认保持用户真实画面。
- 不引入 Appium 作为默认依赖；TritonKit 的优势仍是 embedded runtime + host adapter + machine-readable schema。

## 明确不采用

1. 不把 TritonKit 变成云设备平台、设备云、远端 agent 或多租户服务。
2. 不引入 Revyl 账号、build upload、云 tunnel 或中心 dashboard 作为当前产品面。
3. 不把自然语言 `--target` 当作唯一交互契约；TritonKit 仍优先暴露 AX/geometry/text/role/within/index 等可审计选择器。
4. 不把 Appium、WebDriver 或云 simulator 作为默认 runtime。
5. 不把 screenshot diff、screen exploration、PR bot 合并进当前 emulator takeover 主线；这些都应作为后续独立 space。

## 对当前 roadmap 的影响

### 可直接进入 backlog

1. `triton skill list/install/export`：让 public skills 像 CLI 能力一样可发现、可安装、可校验版本。
2. `triton preflight app`：检查 App 侧 TritonKit DEBUG bootstrap / Release no-op / URL scheme / package 集成。
3. `triton screenshot compare`：本地 baseline/current/diff artifact，支持动态区域 mask。
4. `triton explore/map`：把 screen graph 从 evidence 中拆出来，作为长期探索产物。
5. PR comment template：把 smoke/capture/evidence summary 转成 GitHub PR/issue 可读 Markdown。

### 需要新建 space 后再做

1. 设计稿 Figma diff。
2. AI BFS app exploration。
3. PR diff-aware mobile review。
4. Auth bypass skill family。
5. 云设备、远端 agent 或 build upload。

## 结论

RevylAI 对 TritonKit 的参考价值不在“云设备平台”本身，而在移动可靠性工具链的产品组织方式：

- CLI + skill 是 agent 入口。
- evidence、screen map、visual diff、PR comment 是不同 artifact，不应混成一个文件。
- AI agent 可做探索和评审，但底层命令必须持续输出机器可读 schema。
- 云端和自然语言 target 可以提升易用性，但 TritonKit 当前的差异化仍是本机 CLI、本机 simulator/emulator、embedded runtime 和可审计契约。

因此 #24 可以视为已完成参考归档；后续若要落实现，应从 `skill install/export`、`preflight app`、`screenshot compare`、`explore/map` 四个较小 space 中选择，不直接照搬 RevylAI 的云平台路线。
