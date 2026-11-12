#!/usr/bin/env python3
"""Build the SP-287 offline diagram from the stack-diagram template.
No product process, device, model, CDN, or server is started by this script.
"""
from __future__ import annotations
import hashlib
import html
import json
import pathlib
import os
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[4]
SPACE = pathlib.Path(__file__).resolve().parents[1]
SKILL = pathlib.Path(os.environ.get('STACK_DIAGRAM_SKILL_DIR', str(pathlib.Path.home() / '.agents/skills/stack-diagram'))).expanduser().resolve()
ASSETS = pathlib.Path(os.environ.get('TRITON_FEATURE_MAP_ASSETS_DIR', str(pathlib.Path(tempfile.gettempdir()) / 'tritonkit-feature-map-20261112'))).expanduser().resolve()
W, H = 1800, 1560
NODES = []
EDGES = []


def source(path, line=1):
    return {'path': path, 'line': line}


def node(id, name, icon, role, summary, x, y, category, commands, details, limits, sources, status='已接入'):
    NODES.append(dict(id=id, name=name, icon=icon, role=role, summary=summary, x=x, y=y,
                      category=category, commands=commands, details=details, limits=limits,
                      sources=sources, status=status))


readme = lambda line: source('README.md', line)
surface = lambda line: source('TritonKit.skills/tritonkit-emulator-cli-takeover/references/current-implemented-surface.md', line)
cli = lambda name, line=1: source('Sources/TritonKitCLI/' + name + '.swift', line)

# 01 — Access. Optional adapters are not a mandatory chain.
node('agent', 'AI Agent / 自动化脚本', 'agent', '使用方 · public skills', '读取结构化事实，决定下一步', 200, 232, 'entry',
     ['status / doctor / capabilities / schema / plan', 'JSON / JSONL + public skills'],
     ['外部 agent 与 CI/脚本优先消费 CLI/HTTP；public skills 提供接入、模拟器接管和真实项目回归流程。',
      '业务策略、内容分类与是否执行动作由上层决定；Triton 提供操作与原始数据。'],
     ['plan 是建议，不会自动执行；工具结果、下一步命令和图中关联均不产生执行授权。'],
     [readme(26), readme(70), readme(929)])
node('cli', 'triton CLI', 'cli', '主操作入口 · JSON / JSONL', '诊断、观察、控制、验证与归档', 550, 232, 'entry',
     ['triton <command> --json', 'triton schema --command <command> --json'],
     ['统一 ArgumentParser 命令树；host-side 能力不强制依赖管理 server。',
      'embedded 请求按需经 HTTP/Runtime 通道；Runner CLI 使用相同服务但不要求先启动 serve。'],
     ['当前图基于源码与既有 WIP；安装版应重新查询 version/schema/capabilities。'],
     [cli('TritonKitCLI', 99), readme(126)])
node('http', '本地 HTTP + Runtime 通道', 'http', 'triton serve · 127.0.0.1:19421', 'HTTP 服务与 embedded WebSocket', 900, 232, 'entry',
     ['serve / /status / /targets / /request / /input', '/workspace/* / /v1/device/* / /v1/app-map/*'],
     ['Hummingbird 提供本地机器可读服务；WebSocket 连接 embedded runtime。',
      '注册目标租约、Runner、typed device、workspace、app-map 等路由；不是每条 CLI 命令都有一对一 HTTP API。'],
     ['默认 loopback，Bonjour 默认关闭；不画成设备云、远端 agent 平台或多租户服务。'],
     [cli('CLIServeCommand', 11), readme(485)])
node('dsh', 'DSH 插件', 'dsh', '可选封装 · 4 个工具', 'schema / query / action / verify', 1250, 232, 'entry',
     ['triton_schema', 'triton_query / triton_action / triton_verify'],
     ['Host-only 插件调用已安装 triton CLI，不复制 Swift 核心，也不启动另一个 Web 服务。',
      '仅暴露受限工具子集：显式命名空间 target、串行派发、原始结果与退出状态。'],
     ['要求 DSH Full access；不开放任意 argv、serve、安装/卸载、Runner 生命周期或 replay。',
      '插件接入/测试边界不等于每个真实设备动作都已验收。'],
     [source('DSH/README.md', 26)], '可选 / 有边界')
node('web', 'Web 预览 / 桌面壳', 'web', '只读展示 · 非业务控制面', '设备预览、层级、Run / Atlas', 1600, 232, 'entry',
     ['triton web / web status / web doctor', '/web/targets / /web/device / packaged Web'],
     ['已有 React/Vite 原型、打包 Web 与展示壳；消费只读 DTO、预览、树和证据。',
      '展示与控制的产品边界分开：不能因为页面或按钮存在而宣称正式 Wails 控制面已交付。'],
     ['browser 写路由拒绝；正式 Web/Wails 业务动作不属于本图已支持范围。'],
     [source('AGENTS.md', 45), cli('CLIPackagedWebRuntime', 140), cli('CLIServeCommand', 83)], '只读 / 原型边界')

# 02 — The primary inspection/action/proof loop.
node('discover', '能力发现与诊断', 'discover', 'status · doctor · schema · plan', '知道能做什么，失败如何恢复', 180, 512, 'loop',
     ['version / status / doctor / capabilities', 'schema / plan / debug runtime manifest'],
     ['查询版本、server/runtime 状态、能力清单、参数与输出契约。',
      '保留 unsupported / unknown / recovery nextAction；plan 生成可审核命令建议。'],
     ['supported 与 enabled、ready、业务完成是不同事实；不能以目录/命令名冒充现场可用。'],
     [cli('TritonKitCLI', 105), readme(929)])
node('target', '目标绑定与会话', 'target', 'target / device · alias · lease', '发现设备，明确目标与生命周期', 468, 512, 'loop',
     ['target list/use/current/resolve/wait-ready', 'device list/doctor/alias / target lease'],
     ['区分 host device selector 与 embedded runtime target；多候选拒绝猜测。',
      '可选 TTL 租约由 serve 持有；Runner 有独立认证会话、allowlist 与 request receipt。'],
     ['不是所有动作都接入同一租约 owner；Admission/generation 默认单次或进程内，不是全局 Stop、去重或沙箱。'],
     [readme(520), readme(546), readme(76)])
node('observe', '页面观察与定位', 'observe', 'observe · node · screenshot', '树 / AX / 几何 / OCR / 视觉稳定', 756, 512, 'loop',
     ['observe current/tree/ocr/settle', 'node resolve / debug ax / screenshot'],
     ['统一观察 DTO；outline 与短期 @N alias 支持后续定位，原始 provider 与覆盖边界保留。',
      '截图、OCR 和 settle 分别提供视觉、文字候选与稳定性证据。'],
     ['alias 需新鲜观察；截断不证明缺失；OCR 坐标不是可执行 OID，settled 不证明业务成功。'],
     [readme(695), cli('CLIObservationCommands', 69)])
node('action', '动作执行', 'action', 'act / device actions · provider', '点击、滑动、输入与语义控件', 1044, 512, 'loop',
     ['act find/tap/swipe/type/paste/clear/press', 'act focus/set-text/select-segment/set-switch', 'device tap/double-tap/swipe/press/type'],
     ['统一高层动作按平台/provider 路由；embedded 使用公开可验证控制，host 使用各平台适配器。',
      '当前本地 WIP 为 typed device 与部分 host 路径补 shared actionReceipt 和可选原始证据。'],
     ['并非每个平台都支持每种动作；ACK 只证明提交，timeout/unknown 不自动重放。',
      'receipt 接线并非所有入口统一完成；不能把缺读回误说成禁止输入。'],
     [cli('CLIActionCommands', 1), readme(76), surface(267)], '已接入 / 局部 WIP')
node('verify', '业务等待与断言', 'verify', 'wait · verify · route assertion', '用后置状态判定，而不是看 ACK', 1332, 512, 'loop',
     ['wait --text/--exists/--gone/--predicate', 'verify text-exists/text-not-exists', 'route assert-current-url'],
     ['支持文本/角色/数量/区域等约束；各 provider 保持各自 wait/assert 合同。',
      'workspace、测试与 replay 复用等待/验证语义，区分 passed / failed / uncertain。'],
     ['Host wait 不等于所有 embedded predicate 可用；读回 unavailable 时不得伪造验证通过。'],
     [readme(848), surface(216), cli('CLIEvidenceCommands', 350)])
node('evidence', '证据与原始事实', 'evidence', 'evidence · export · receipt', 'manifest、截图、树、日志与 SHA', 1620, 512, 'loop',
     ['evidence capture/inspect/summary/redact', 'export / --evidence-dir / actionReceipt'],
     ['证据包关联状态、目标、截图、层级、几何、run events 与 artifacts；保留来源和 partial。',
      'SP-281/SP-286 本地增强保留 provider JSON/已捕获 host 输出，显式转换与原始数据分离。'],
     ['manifest.ok 是采集完整性，不是动作或业务成功；原值保留不授权公开发布。',
      '历史已删内容不能冒充恢复；摘要/截断/不可读取值必须明确。'],
     [readme(70), readme(76), readme(920)], '已接入 / 局部 WIP')

# 03 — Capability extensions. A category is not a promise of platform parity.
node('app', '设备与 App 管理', 'app', 'device · sim · app · resource', '启停、安装、环境、容器与资源', 180, 846, 'extension',
     ['device start/stop/orientation/location/clipboard', 'app list/info/inspect/install/launch/open-url', 'sim runtime/privacy/push/logs / device resource'],
     ['跨平台发现、App 生命周期、录屏/日志/crash/mirror；iOS 还包括容器、preferences 与 sim 维护。',
      '资源管理提供 plan/apply/verify/restore 和 receipt；权限与可控项依平台而定。'],
     ['剪贴板 staging 不等于输入完成；安装/启动不等于业务就绪；不承诺固定内存收益。',
      'DerivedData 通用自动删除已取消，只保留 inspect/preview 与 confirm 拒绝。'],
     [surface(3), surface(31), readme(579)])
node('webview', 'WebView 与网络', 'webview', 'webview · route · proxy', 'DOM / 表单 / bridge / 请求证据', 468, 846, 'extension',
     ['webview list/current/current-url/snapshot', 'webview focus/type/set-text/call/events/wait', 'act tap --webview-aware / device proxy / sim proxy'],
     ['有 provider 时读取有界 WebView snapshot、URL、页面事件与 allowlist bridge；表单输入显式 opt-in。',
      'host proxy/证书/网络采集另有环境前提；业务 URL/请求/响应原值与显式转换分开。'],
     ['容器候选不等于 DOM/bridge 可用；DOM click trusted=false，需后置验证。',
      '不是全平台任意 JS eval；网络解密/证书信任与页面权限不由命令存在保证。'],
     [surface(231), readme(356), cli('CLIHostDeviceCommands', 120)])
node('inspect', 'UI 深度调试', 'inspect', 'hierarchy · details · highlight', '视图属性、节点截图、3D 与标记', 756, 846, 'extension',
     ['debug hierarchy/snapshot/details/attrs', 'inspect selection / highlight', 'export --format archive'],
     ['iOS embedded 提供视图树、几何、属性、节点截图与 Lookin 核心检查数据。',
      '浮动 picker / SDK hub、selection 与独立 highlight 支持定位；Web 可投影层级与 3D 场景。'],
     ['深度 UIKit 能力依赖 Debug SDK、capability gate 与具体属性/provider；不代表 Android/Harmony 全量对齐。'],
     [source('docs-linhay/dev/20261103-lookin-core-inspection.md'), cli('CLIInspectionCommands', 177), readme(362)])
node('build', '构建与工程诊断', 'build', 'xcode · build · xcresult', '发现工程、构建测试、产物诊断', 1044, 846, 'extension',
     ['xcode discover/schemes/settings/build/test/run', 'xcode archive/export / xcresult summary/failures', 'xctrace / coverage / build'],
     ['Xcode 项目/workspace/Swift package 工作流输出 JSON/JSONL、有界进度和日志 artifacts。',
      '跨平台 build 命令按 backend 分流；构建产物衔接安装与启动，结果/trace/coverage 支持诊断。'],
     ['构建成功、签名、安装、启动和业务就绪分开；本图不重新执行任何构建或签名验收。'],
     [readme(720), cli('CLIBuildCommands', 1)])
node('replay', '测试、录制与回放', 'replay', 'record / replay · test · smoke', '显式计划、执行、断言与恢复', 1332, 846, 'extension',
     ['record / plan inspect / replay --dry-run', 'test import/validate/run / smoke ios/android/harmony', 'testrec start/event/stop/compile'],
     ['.tritonplan 支持显式短流程回放；test runner 使用计划、业务断言和 evidence 形成结果。',
      'testrec 是显式事件采集/编译，import 后经过 validate，再由 test run 执行；不是自动录制所有用户行为。'],
     ['testrec local-simulated/matrix 仅 offline diagnostic，不计真实 verdict。',
      '真实 3×20+negative 可靠性采样未完成，不作量化可靠性承诺。'],
     [readme(640), readme(659), readme(669), readme(940), cli('CLITestRecorderCommands', 1)])
node('workspace', 'Workspace / Atlas', 'workspace', 'workspace · map · 可选推理', 'App-map：状态迁移、覆盖与路径', 1620, 846, 'extension',
     ['workspace run/inspect/stop/export-flow/merge-map', 'map inspect/health/path/suite/export-flow', 'vlm ground/compare/models'],
     ['将 observation、动作、wait/assert、证据串成有界 Run；Atlas 记录状态与转移，App-map 跨 Run 聚合覆盖。',
      '可导出测试路径；OpenAI-compatible / 本地 MLX LLM/VLM 为可选辅助，不是默认必经服务。'],
     ['推理默认关闭，需 --enable-llm/--enable-vlm；真实动作需 --execute-actions。',
      '模型配置不等于启用，候选迁移不等于 verified；不存在统一常驻全入口任务 owner 承诺。'],
     [surface(72), readme(691), readme(718), cli('CLIAppMapCommands', 5)], '已接入 / 推理可选')

# 04 — Platform adapters, deliberately separate from entry/control capabilities.
node('ioshost', 'iOS Simulator Host', 'apple', 'simctl · Host AX · 内置 HID', '免 App SDK：设备、画面与基础操作', 200, 1162, 'platform',
     ['sim / device / app --platform ios', 'observe tree / wait --platform ios', 'sim screenshot / native HID tap/swipe'],
     ['本机模拟器生命周期、App 安装/启动、framebuffer、Host AX 与隔离 HID 适配器。',
      '选中 Xcode 与 geometry/screen/target 校验是输入前提。'],
     ['sim type 为 reserved unsupported；不可把 clipboard stage 当自动 paste。',
      'Host AX/HID 不用于真机；Resize/主屏限制按实际 capability 判断。'],
     [surface(90), surface(250), readme(870)])
node('iossdk', 'iOS Embedded SDK', 'swift', 'SwiftPM · iOS 16+ · Debug only', '应用内公开 API：树、语义、输入', 550, 1162, 'platform',
     ['TritonKit.shared.start() / debug runtime manifest', 'debug snapshot / act / webview / screenshot'],
     ['App 自有 Debug bootstrap 注册连接与能力；提供 UIKit 观察、几何、截图、表单、WebView 和语义状态。',
      '可用于连接中的 Simulator/真机 App runtime；与 host target 及 Runner 会话分开。'],
     ['Release no-op；依 app-owned feature gate。语义 action catalog 主要是发现元数据，不等于通用业务 action perform 已实现。'],
     [readme(130), readme(195), readme(909)])
node('runner', 'iOS XCTest Runner', 'xcode', 'Simulator / USB 真机 · 独立会话', '免 App SDK：inspect、tap、type', 900, 1162, 'platform',
     ['device runner doctor/prepare/start/status/stop', 'device runner activate/inspect/tap/scroll/type', 'device runner screenshot/receipt'],
     ['bundled XCTest Runner 通过 Mac/Xcode 构建签名，受认证、TTL、allow-bundle 与新鲜 selector 约束。',
      '真机路径独立于 Simulator host adapter；request-id/receipt 用于不确定送达后的事实恢复。'],
     ['配对/信任、开发者模式、签名、解锁和 UI Automation 授权仍是前提。',
      '不是脱离 Mac 常驻服务；Safari 输入/导航未现场通过；通用 device screenshot 不因此获得真机支持。'],
     [readme(84), readme(782)])
node('android', 'Android Emulator', 'android', 'ADB · UIAutomator / Bridge', '设备、App、布局、输入与截图', 1250, 1162, 'platform',
     ['device / app / observe / wait / act --platform android', 'device bridge / device resource / smoke android'],
     ['ADB host-side 生命周期、UIAutomator layout 与输入、截图；Bridge 提供增强会话/能力。',
      'Android-specific resource/profile 与 capture 能力按实际 provider/权限判断。'],
     ['默认聚焦本机 Emulator；legacy input text 的 Unicode/keymap/%s 限制保留，tree/Bridge 不可用时不猜旧坐标。'],
     [surface(248), readme(784), source('Tools/AndroidBridge/README.md', 1)])
node('harmony', 'HarmonyOS / DevEco', 'harmony', 'HDC · uitest · ArkWeb', '布局、输入、截图与页面适配', 1600, 1162, 'platform',
     ['device / app / observe / wait / act --platform harmony', 'device runtime-url / webview / build'],
     ['Host HDC 路径免 embedded SDK；uitest layout/input 与 snapshot_display 返回原始事实。',
      'ArkWeb/CDP 与 standalone embedded runtime 有各自 provider/会话前提，不与 HDC 容器候选混同。'],
     ['verified input 受 IME/读回能力限制；不可读值报 unavailable，不伪造验证。',
      'clear 及部分环境/资源项 unsupported；不是三端全量对齐。'],
     [surface(152), surface(177), readme(817)])


def edge(id, start, end, label, d, x, y, kind='internal', anchor='middle'):
    EDGES.append(dict(id=id, start=start, end=end, label=label, d=d, x=x, y=y, kind=kind, anchor=anchor))

edge('agent-cli', 'agent', 'cli', '命令 / JSON', 'M242 262 H508', 375, 250, 'primary')
edge('cli-http', 'cli', 'http', '按需请求', 'M592 262 H858', 725, 250)
edge('dsh-cli', 'dsh', 'cli', '可选 CLI 工具封装', 'M1250 226 V206 H550 V226', 900, 198)
edge('http-web', 'http', 'web', '只读 DTO / 预览', 'M900 378 V410 H1600 V378', 1260, 400)
edge('cli-discover', 'cli', 'discover', '主工作流', 'M550 378 V426 H28 V542 H138', 330, 416, 'primary')
edge('http-target', 'http', 'target', '共享服务', 'M900 378 V444 H468 V506', 730, 435)
for a, b, text, cx1, cx2 in [
    ('discover','target','确认能力',180,468), ('target','observe','绑定目标',468,756),
    ('observe','action','选择节点',756,1044), ('action','verify','检查后置',1044,1332),
    ('verify','evidence','保留事实',1332,1620)]:
    edge(a+'-'+b, a, b, text, f'M{cx1+42} 542 H{cx2-42}', (cx1+cx2)/2, 530, 'primary')
edge('verify-observe', 'verify', 'observe', '需要继续时重新观察，不重放未知动作', 'M1332 658 V712 H756 V658', 1044, 702)
edge('target-app', 'target', 'app', '准备设备 / App', 'M468 658 V770 H28 V876 H138', 324, 760)
edge('observe-inspect', 'observe', 'inspect', '深入检查', 'M756 658 V840', 769, 792, anchor='start')
edge('action-webview', 'action', 'webview', 'Web 表单 / bridge', 'M1044 658 V750 H468 V840', 554, 740)
edge('verify-replay', 'verify', 'replay', '复用断言', 'M1332 658 V840', 1345, 789, anchor='start')
edge('evidence-workspace', 'evidence', 'workspace', '聚合状态与路径', 'M1620 658 V840', 1633, 785, anchor='start')
edge('replay-evidence', 'replay', 'evidence', '执行产出证据', 'M1374 876 H1476 V674 H1620 V658', 1490, 813, anchor='start')
edge('build-app', 'build', 'app', '构建产物 → 安装 / 启动', 'M1044 992 V1064 H180 V992', 626, 1054, 'dev')
# The broad dispatch bus represents adapter selection, not universal per-feature parity.
edge('app-ioshost', 'app', 'ioshost', '', 'M180 992 V1090 H28 V1192 H158', 0, 0)
edge('inspect-iossdk', 'inspect', 'iossdk', '深度应用内能力', 'M756 992 V1080 H550 V1156', 650, 1070)
edge('action-runner', 'action', 'runner', '独立 Runner 会话', 'M1086 542 H1168 V1098 H900 V1156', 1026, 1088)
edge('app-android', 'app', 'android', '', 'M180 1090 H1250 V1156', 0, 0)
edge('app-harmony', 'app', 'harmony', '', 'M1250 1090 H1600 V1156', 0, 0)
edge('app-iossdk', 'app', 'iossdk', '', 'M200 1090 H550 V1156', 0, 0)
# State/data relationship inside the optional workflow cluster.
edge('workspace-replay', 'workspace', 'replay', '导出 flow', 'M1578 876 H1374', 1476, 864)

assert len(NODES) == 22
ids = {n['id'] for n in NODES}
assert len(ids) == len(NODES)
for e in EDGES:
    assert e['start'] in ids and e['end'] in ids
for n in NODES:
    for s in n['sources']:
        assert (ROOT / s['path']).is_file(), s


def esc(s): return html.escape(str(s), quote=True)


def render_node(n):
    style = f"left:{n['x']-114}px;top:{n['y']}px"
    return (f'<button type="button" class="node {n["category"]}" data-id="{n["id"]}" style="{style}" '
            f'aria-label="{esc(n["name"])}：{esc(n["summary"])}；点击查看详情" aria-pressed="false">'
            f'<span class="tile"><img src="%%ICON_{n["icon"]}%%" alt=""></span>'
            f'<span class="name"><span>{esc(n["name"])}</span></span>'
            f'<span class="role"><span>{esc(n["role"])}</span></span>'
            f'<span class="summary">{esc(n["summary"])}</span></button>')


def render_edge(e):
    css = {'primary': 'e', 'internal': 'n', 'dev': 'n dash'}[e['kind']]
    text = (f'<text class="el {"a" if e["kind"]=="primary" else ""}" x="{e["x"]}" y="{e["y"]}" '
            f'text-anchor="{e["anchor"]}">{esc(e["label"])}</text>') if e['label'] else ''
    return (f'<g class="connection" data-start="{e["start"]}" data-end="{e["end"]}" data-edge="{e["id"]}">'
            f'<path class="{css}" d="{e["d"]}" marker-end="url(#ar)"/>{text}</g>')

css = '''
:root{--font-display:"Geist","PingFang SC","Microsoft YaHei","Noto Sans CJK SC",sans-serif;--font-body:"PingFang SC","Microsoft YaHei","Noto Sans CJK SC",sans-serif;--color-success:oklch(50% .11 165);--color-warning:oklch(55% .12 70);--color-border-soft:oklch(86% .018 255);--color-tile:#fff;--color-shadow:oklch(24% .02 258 / .05)}
[data-theme="dark"]{--color-success:oklch(78% .11 165);--color-warning:oklch(80% .12 70);--color-border-soft:oklch(41% .018 255)}
body{padding:24px}.page{width:1800px;max-width:100%}.head{margin-bottom:16px;align-items:center}.head h1{font-size:18px}.head .lede{max-width:none;font-size:12px}.controls{display:flex;gap:8px;align-items:center;flex-wrap:wrap}.controls button{font:12px var(--font-body);padding:8px 12px;border:1px solid var(--color-rule-2);border-radius:7px;background:var(--color-paper-2);color:var(--color-ink);cursor:pointer}.controls button:hover{border-color:var(--color-accent)}.controls button:focus-visible,.node:focus-visible{outline:3px solid var(--color-accent);outline-offset:4px}.scroller{width:100%;overflow:auto}.stage{position:relative;width:1800px;height:1560px}.canvas{transform-origin:top left}.canvas-title{position:absolute;left:58px;top:38px}.canvas-title .kicker{font-size:12px}.canvas-title h2{font-family:var(--font-display);font-size:36px;line-height:1.3;letter-spacing:-.025em}.canvas-title p{margin-top:10px;font-size:14px;color:var(--color-neutral)}.snapshot{position:absolute;right:60px;top:48px;text-align:right;font-size:12px;line-height:1.9;color:var(--color-muted)}.snapshot strong{display:block;color:var(--color-ink);font-size:16px;font-weight:600}.group{border-radius:12px;border:1px solid var(--color-border-soft);background:var(--color-accent-tint)}.group.entry-group{background:var(--color-paper-2)}.group.loop-group{border-color:var(--color-accent-soft)}.group.extension-group{background:var(--color-g1-tint);border-color:var(--color-g1-soft)}.group.platform-group{background:var(--color-paper-2)}.g-label{top:15px;left:20px;font-size:14px;gap:12px}.g-label b{font-family:var(--font-mono);font-weight:500;color:var(--color-muted);font-size:11px}.g-note{position:absolute;right:20px;top:15px;font-size:11px;color:var(--color-muted);line-height:20px}.node{appearance:none;width:228px;border:0;background:none;font:inherit;color:inherit;cursor:pointer;display:block;border-radius:9px;padding:0 4px;transition:opacity .16s}.node .tile{display:grid;width:60px;height:60px;border-radius:12px;background:var(--color-tile);box-shadow:0 1px 2px var(--color-shadow)}.node .name{display:block;font-family:var(--font-display);font-size:16px;line-height:23px;margin-top:8px;font-weight:650}.node .role{display:block;font-family:var(--font-mono);font-size:10.5px;letter-spacing:.015em;line-height:19px;color:var(--color-muted);margin-top:1px;white-space:nowrap}.node .summary{display:block;font-size:12px;line-height:20px;color:var(--color-neutral);margin-top:4px;white-space:nowrap}.node.selected .tile{border:2px solid var(--color-accent);box-shadow:0 0 0 5px var(--color-accent-tint)}.node.related .tile{border-color:var(--color-accent)}.canvas.has-selection .node:not(.selected):not(.related){opacity:.32}.canvas.has-selection .connection:not(.related){opacity:.14}.connection{transition:opacity .16s}.connection.related path{stroke-width:2.8}.el{font-family:var(--font-body);font-size:12px;letter-spacing:0;stroke-width:6px}.e{stroke-width:2}.n{stroke-width:1.4}.dispatch-note{position:absolute;top:1121px;right:66px;font-size:11px;color:var(--color-muted)}.notes{position:absolute;left:58px;right:58px;top:1370px;display:grid;grid-template-columns:1.1fr 1fr;gap:38px;border-top:1px solid var(--color-rule-2);padding-top:18px;font-size:13px;line-height:1.9;color:var(--color-neutral)}.notes h3{font-size:13px;color:var(--color-ink);margin-bottom:3px}.notes strong{color:var(--color-ink);font-weight:600}.canvas-legend{position:absolute;left:58px;right:58px;bottom:30px;display:flex;gap:28px;align-items:center;font-size:11px;color:var(--color-muted)}.canvas-legend .sw{display:inline-block;width:32px;vertical-align:middle;margin-right:8px;border-top:2px solid var(--color-accent)}.canvas-legend .sw.n{border-color:var(--color-neutral);border-width:1.4px}.canvas-legend .sw.dash{border-top-style:dashed}.canvas-legend .basis{margin-left:auto;font-family:var(--font-mono);font-size:10px}.detail{margin-top:20px;border:1px solid var(--color-rule-2);border-radius:10px;padding:24px;background:var(--color-paper-2)}.detail-heading{display:flex;align-items:center;gap:14px;flex-wrap:wrap;margin-bottom:16px}.detail h2{font-size:20px}.badge{padding:3px 9px;border:1px solid var(--color-rule-2);border-radius:20px;font-size:11px;color:var(--color-warning)}.detail-grid{display:grid;grid-template-columns:1.05fr 1fr 1fr;gap:30px}.detail h3{font-size:12px;color:var(--color-muted);font-weight:600;margin-bottom:8px}.detail p,.detail li{font-size:13px;line-height:1.9}.detail ul{padding-left:18px}.detail code{display:block;white-space:pre-wrap;word-break:break-word;font-family:var(--font-mono);font-size:11px;line-height:1.9;color:var(--color-accent);margin-bottom:7px}.detail a{color:var(--color-accent);font-size:12px;text-decoration-thickness:1px;text-underline-offset:3px}.detail .sources{margin-top:18px;border-top:1px solid var(--color-rule-2);padding-top:14px;display:flex;gap:16px;flex-wrap:wrap}.detail-empty{font-size:13px;color:var(--color-muted)}.foot{font-size:10px;line-height:1.8;margin-top:22px}.foot .note{max-width:760px}@media(max-width:900px){.head{grid-template-columns:1fr}.detail-grid{grid-template-columns:1fr}.detail{padding:18px}.head .lede{max-width:none}}
'''

markers = '''<defs><marker id="ar" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6.5" markerHeight="6.5" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="context-stroke"/></marker></defs>'''
groups = '''
<div class="group entry-group" style="left:42px;top:164px;width:1716px;height:230px"><div class="g-label"><b>01 / ACCESS</b> 使用入口</div><div class="g-note">CLI 是主操作面 · HTTP 按需 · DSH 可选 · Web 只读</div></div>
<div class="group loop-group" style="left:42px;top:452px;width:1716px;height:280px"><div class="g-label"><b>02 / CONTROL LOOP</b> 从发现到可验收的闭环</div><div class="g-note">蓝色箭头为主线，其他连线为关键依赖或数据关系</div></div>
<div class="group extension-group" style="left:42px;top:786px;width:1716px;height:248px"><div class="g-label"><b>03 / CAPABILITIES</b> 复用主线的扩展能力</div></div>
<div class="group platform-group" style="left:42px;top:1100px;width:1716px;height:240px"><div class="g-label"><b>04 / PROVIDERS</b> 平台与执行适配器</div></div>
'''
chart_head = f'''<div class="canvas-title"><div class="kicker">TRITONKIT / CAPABILITY ATLAS</div><h2>TritonKit 当前功能与关联</h2><p>操作与数据提供层：连接设备、理解界面、执行动作，再用业务后置状态和证据形成闭环。</p></div><div class="snapshot"><strong>22 能力节点 · {len(EDGES)} 条关键关联</strong>2026-11-12 · main@6467b413 + 本地 WIP<br>源码/契约快照 ≠ 发布版全量能力 ≠ 今日现场验收</div>'''
notes = '''<div class="dispatch-note">按目标与 provider 选择路径；不是每条功能都覆盖全部平台</div>
<section class="notes"><div><h3>贯穿全链路的技术约束</h3>显式目标 / 会话、能力开关、可选租约、超时与预算、原始 provider 事实。<br><strong>ACK ≠ 业务完成；unknown 不自动重放；manifest.ok ≠ 动作成功。</strong></div><div><h3>当前支持的边界</h3>iOS Host / Embedded / Runner 分开；Web 是只读展示；LLM / VLM 默认关闭。<br>真机按具体命令与会话判断；不包含设备云、多租户、正式 Wails 控制面。</div></section>
<div class="canvas-legend"><span><i class="sw"></i>主工作流</span><span><i class="sw n"></i>调用 / 数据 / 能力关联</span><span><i class="sw n dash"></i>构建产物衔接</span><span class="basis">READ SOURCE → CHECK CAPABILITY → EXECUTE → VERIFY → PROVE</span></div>'''

body = '''<div class="page"><header class="head"><div><h1>功能关联图 · 交互版</h1><p class="lede">选择节点可高亮一跳关联并查看命令与限制；图片导出保留完整概览。</p></div><div class="controls"><button id="fit" type="button">适应窗口</button><button id="actual" type="button">1:1 查看</button><button id="reset" type="button">重置高亮</button><button id="theme" type="button" aria-pressed="false">切换深色</button></div></header><div class="scroller"><div class="stage"><main class="canvas" aria-label="TritonKit 当前功能与关联图">'''
body += chart_head + groups + f'<svg class="edges" viewBox="0 0 {W} {H}" aria-hidden="true">' + markers
body += ''.join(map(render_edge, EDGES)) + '</svg>' + ''.join(map(render_node, NODES)) + notes
body += '''</main></div></div><section class="detail" id="detail" aria-live="polite"><p class="detail-empty">选择任意功能节点：查看支持内容、命令入口、相邻功能、事实来源与边界。</p></section><footer class="foot"><span class="note">本图是当前源码功能地图，不是全平台 E2E 验收报告。图标：svgl / devicon / Lucide；Harmony 节点使用通用设备图符。品牌标志归各权利人所有。</span><span>made with <a href="https://github.com/caru-ini/stack-diagram" target="_blank" rel="noopener">stack-diagram</a></span></footer></div>'''
model = json.dumps({'nodes': NODES, 'edges': EDGES, 'baseline': 'main@6467b413 + existing WIP', 'date': '2026-11-12'}, ensure_ascii=False).replace('<', '\\u003c')
script = '''
const graph=JSON.parse(document.getElementById('graph-data').textContent);
const byId=new Map(graph.nodes.map(n=>[n.id,n]));
const canvas=document.querySelector('.canvas');
const detail=document.getElementById('detail');
const escapeHtml=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function clearSelection(){canvas.classList.remove('has-selection');document.querySelectorAll('.node').forEach(el=>{el.classList.remove('selected','related');el.setAttribute('aria-pressed','false')});document.querySelectorAll('.connection').forEach(el=>el.classList.remove('related'))}
function choose(id){clearSelection();const n=byId.get(id);if(!n)return;canvas.classList.add('has-selection');const adjacent=new Set();for(const e of graph.edges){if(e.start===id||e.end===id){adjacent.add(e.start);adjacent.add(e.end);document.querySelector('[data-edge="'+e.id+'"]').classList.add('related')}}document.querySelectorAll('.node').forEach(el=>{el.classList.toggle('selected',el.dataset.id===id);el.classList.toggle('related',el.dataset.id!==id&&adjacent.has(el.dataset.id));el.setAttribute('aria-pressed',String(el.dataset.id===id))});const related=[...adjacent].filter(x=>x!==id).map(x=>byId.get(x).name);detail.innerHTML='<div class="detail-heading"><h2>'+escapeHtml(n.name)+'</h2><span class="badge">'+escapeHtml(n.status)+'</span></div><div class="detail-grid"><div><h3>支持内容</h3><ul>'+n.details.map(x=>'<li>'+escapeHtml(x)+'</li>').join('')+'</ul><h3 style="margin-top:14px">相邻功能</h3><p>'+escapeHtml(related.join(' · ')||'见平台与命令契约')+'</p></div><div><h3>命令 / 契约入口（不是可直接执行的参数示例）</h3>'+n.commands.map(x=>'<code>'+escapeHtml(x)+'</code>').join('')+'</div><div><h3>前提与未覆盖范围</h3><ul>'+n.limits.map(x=>'<li>'+escapeHtml(x)+'</li>').join('')+'</ul></div></div><div class="sources"><span>事实来源</span>'+n.sources.map(s=>'<a href="../../../'+encodeURI(s.path)+'#L'+s.line+'" target="_blank" rel="noopener">'+escapeHtml(s.path.split('/').pop())+':'+s.line+'</a>').join('')+'</div>'}
document.querySelectorAll('.node').forEach(el=>el.addEventListener('click',()=>choose(el.dataset.id)));
document.getElementById('reset').addEventListener('click',()=>{clearSelection();detail.innerHTML='<p class="detail-empty">已重置；选择节点查看命令、关联和边界。</p>'});
document.getElementById('theme').addEventListener('click',()=>{const dark=document.documentElement.dataset.theme!=='dark';document.documentElement.dataset.theme=dark?'dark':'light';document.getElementById('theme').setAttribute('aria-pressed',String(dark));document.getElementById('theme').textContent=dark?'切换浅色':'切换深色'});
let fitted=true;function resize(){const scale=fitted?Math.min(1,document.querySelector('.scroller').clientWidth/1800):1;canvas.style.transform='scale('+scale+')';document.querySelector('.stage').style.width=(1800*scale)+'px';document.querySelector('.stage').style.height=(1560*scale)+'px'}
document.getElementById('fit').addEventListener('click',()=>{fitted=true;resize()});document.getElementById('actual').addEventListener('click',()=>{fitted=false;resize()});window.addEventListener('resize',resize);resize();
window.__diagram={graph,choose,clearSelection,resize};
'''
template = (SKILL / 'assets/template.html').read_text(encoding='utf-8')
style = template[template.index('<style>')+7:template.index('</style>')]
style = style.replace('width: 1000px; height: 540px', f'width: {W}px; height: {H}px')
style = style.replace('width:1000px; height:540px', f'width:{W}px; height:{H}px')
# Only one product HTML entry is kept in the space. The temporary draft is build input.
draft = '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>TritonKit 当前功能与关联</title><style>' + style + css + '</style></head><body>' + body + '<script id="graph-data" type="application/json">' + model + '</script><script>' + script + '</script></body></html>'
ASSETS.mkdir(parents=True, exist_ok=True)
(ASSETS / 'draft.html').write_text(draft, encoding='utf-8')
(SPACE / 'plans/20261112-feature-model.json').write_text(json.dumps({'nodes':NODES,'edges':EDGES}, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
subprocess.run(['python3', str(SKILL/'scripts/build.py'), str(ASSETS/'draft.html'), str(ASSETS/'icons'), str(SPACE/'feature-map.html'), '--fonts', str(SKILL/'assets/fonts')], check=True)
print(f'Validated {len(NODES)} unique nodes, {len(EDGES)} relationships, all source paths exist.')
print('HTML SHA-256:', hashlib.sha256((SPACE/'feature-map.html').read_bytes()).hexdigest())
