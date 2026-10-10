"""Render the SP-182 proposal diagram to editable SVG and PNG; no device actions."""
from pathlib import Path
from html import escape
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
PNG = ROOT / 'screenshots/20261008-architecture-overview-proposal-v2.png'
SVG = ROOT / '20261008-trusted-execution-architecture-v2.svg'
W, H = 2200, 1940
im = Image.new('RGB', (W, H), '#f5f7fb')
draw = ImageDraw.Draw(im)
svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">', '<title>TritonKit 新可信执行系统：多端统一语义架构（设计提案）</title>', '<desc>统一语义经唯一执行内核调用本机平台适配器，回执与新观察参与独立验证、资源恢复和证据提交。模型只提议，Web/Wails只读，旧编排被消融。不是已实现系统。</desc>', f'<rect width="{W}" height="{H}" fill="#f5f7fb"/>']
COL = {'ink': '#14263f', 'muted': '#5b6c82', 'blue': '#356ce7', 'teal': '#118a82', 'amber': '#a76d13', 'line': '#d9e2ef'}
fonts = {}

def font(size, bold=False):
    key = (size, bold)
    if key not in fonts:
        fonts[key] = ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc' if bold else '/System/Library/Fonts/STHeiti Light.ttc', size)
    return fonts[key]

def rect(x, y, w, h, fill='#ffffff', stroke=None, radius=20, width=2):
    draw.rounded_rectangle((x, y, x+w, y+h), radius, fill, outline=stroke, width=width)
    svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke or "none"}" stroke-width="{width}"/>')

def text(x, y, value, size=26, color=None, bold=False, max_width=None):
    f = font(size, bold)
    if max_width is not None:
        assert draw.textlength(value, font=f) <= max_width, f'Text overflow: {value}'
    color = color or COL['ink']
    draw.text((x, y), value, fill=color, font=f, anchor='lt')
    weight = '600' if bold else '400'
    svg.append(f'<text x="{x}" y="{y}" dominant-baseline="text-before-edge" font-family="Heiti SC, PingFang SC, Arial Unicode MS, sans-serif" font-size="{size}" font-weight="{weight}" fill="{color}">{escape(value)}</text>')

def arrow(points, color=None, dashed=False, width=3):
    color = color or COL['blue']
    if not dashed:
        draw.line(points, fill=color, width=width, joint='curve')
    else:
        for (x1,y1),(x2,y2) in zip(points, points[1:]):
            length=math.hypot(x2-x1,y2-y1)
            for d in range(0, int(length), 15):
                a=d/length; b=min(d+8,length)/length
                draw.line((x1+(x2-x1)*a,y1+(y2-y1)*a,x1+(x2-x1)*b,y1+(y2-y1)*b), fill=color,width=width)
    (x0,y0),(x1,y1)=points[-2:]
    angle=math.atan2(y1-y0,x1-x0)
    p=[(x1,y1),(x1-12*math.cos(angle-.45),y1-12*math.sin(angle-.45)),(x1-12*math.cos(angle+.45),y1-12*math.sin(angle+.45))]
    draw.polygon(p,fill=color)
    path=' '.join(f'{x},{y}' for x,y in points)
    dash=' stroke-dasharray="8 7"' if dashed else ''
    svg.append(f'<polyline points="{path}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round"{dash}/>')
    svg.append(f'<polygon points="{" ".join(f"{x},{y}" for x,y in p)}" fill="{color}"/>')

def panel(x,y,w,h,title,fill='#ffffff',stroke=None):
    rect(x,y,w,h,fill,stroke or COL['line'])
    size = 32
    while draw.textlength(title, font=font(size, True)) > w-56 and size > 24:
        size -= 1
    text(x+28,y+25,title,size,bold=True,max_width=w-56)

def lines(x,y,items,size=25,color=None,gap=38,max_width=None):
    for i,item in enumerate(items):text(x,y+i*gap,item,size,color,max_width=max_width)

# Title and legend.
text(60,42,'TritonKit · 新可信执行系统',54,bold=True)
text(62,112,'单点自由编排  /  高级命令封装  /  共享执行核心与多端统一语义',29,COL['muted'])
rect(1790,42,350,58,'#e9efff',radius=14)
text(1815,57,'设计提案 · 尚未实现',28,COL['blue'],True)

# 01: machine-facing access.
panel(60,180,1500,132,'01  Agent 双操作面  ·  CLI / HTTP')
chips=[('A  单点：observe / act / verify / evidence',90,700),('B  高级：replay / workspace / 封装流程',820,710)]
for label,x,w in chips:
    rect(x,240,w,48,'#f0f4fb',radius=10)
    text(x+18,251,label,25,max_width=w-36)
text(95,325,'A 由 agent 自行组合与验收；B 由系统托管编排。单点无需先创建 Run 或 session。',25,COL['muted'])
arrow([(810,352),(810,385)])

# 02: cross-platform semantic contract and compiler.
panel(60,395,1500,218,'02  多端统一语义层  ·  Semantic Contract','#eef3ff','#a6bff5')
rect(90,462,700,103,'#ffffff','#d2def5',12)
text(112,480,'意图 / 效果 / 条件 / 观察 / 能力 / 结果',28,bold=True,max_width=655)
text(112,527,'activate · set-value · reveal · launch · verify',25,COL['muted'],max_width=655)
rect(820,462,710,103,'#ffffff','#d2def5',12)
text(842,480,'Compiler + Capability Matching',28,bold=True,max_width=665)
text(842,527,'OperationSpec / RunSpec；保证不足不静默降级',25,COL['muted'],max_width=665)
text(94,581,'统一语义 ≠ 同名命令；unknown 不补 false；能力不足不静默降级',25,COL['blue'])
arrow([(810,613),(810,660)])

# 03: sole kernel, step flow and resource coordination.
panel(60,670,1500,477,'03  执行子系统  ·  可选 WorkflowEngine + 共享 ExecutionCore','#ffffff','#356ce7')
text(92,728,'WorkflowEngine（B 高级路径）：Run 编排、业务验收、恢复与证据聚合',26,COL['muted'])
text(832,632,'B 高级流程',22,COL['blue'])
arrow([(60,500),(30,500),(30,1096),(90,1096)])
text(94,1040,'A 单点直达共享 Core，不经过完整工作流',22,COL['blue'])
xs=[90,450,810,1170]
items=[
    (xs[0],780,'1  Bind','设备 / App / runtime 身份'),
    (xs[1],780,'2  Observe','来源 / 新鲜度 / coverage'),
    (xs[2],780,'3  Resolve','唯一目标 / 几何 / scope'),
    (xs[3],780,'4  Guard','能力 / 策略 / writer 授权'),
    (xs[3],930,'5  Dispatch','Attempt / Receipt 事实'),
    (xs[2],930,'6  Fresh Observe','后置观察；拒绝陈旧证据'),
    (xs[1],930,'7  Verify','声明条件 → 独立证据结论'),
    (xs[0],930,'8  Reconcile / Finalize','调和 / 恢复 / 提交 / 裁决'),
]
for x,y,title,sub in items:
    rect(x,y,330,103,'#f3f6fc','#dce5f3',13)
    text(x+18,y+18,title,26,bold=True,max_width=294)
    text(x+18,y+61,sub,22,COL['muted'],max_width=294)
for a,b in zip(xs,xs[1:]):arrow([(a+330,831),(b,831)])
arrow([(1335,883),(1335,930)])
for a,b in [(1170,810),(810,450),(450,90)]:arrow([(a,981),(b+330,981)])
rect(90,1070,1440,51,'#eaf6f4',radius=10)
text(111,1083,'共享 ExecutionCore：绑定 / 观察 / 解析 / 授权与协调 / dispatch / verify / evidence',25,COL['teal'],max_width=1395)

# The kernel talks to registry using requests and receives facts.
arrow([(700,1147),(700,1220)])
text(286,1170,'执行 / 观察请求（唯一 dispatch 路径）',24,COL['blue'])
arrow([(980,1220),(980,1147)],COL['teal'])
text(1000,1170,'回执 / 新观察 / 限制',24,COL['teal'])

# 04: platform adapters; framework details are encapsulated.
panel(60,1230,1500,242,'04  Adapter Registry  ·  统一能力契约，封装平台实现')
platforms=[(90,'iOS Simulator','Embedded Debug / Host Adapter','UIKit runtime / simctl / helper'),(580,'Android Emulator','现有 host / runtime 路径','adb 与平台 provider'),(1070,'Harmony Emulator','现有 host / runtime 路径','hdc 与平台 provider')]
for x,title,sub,tool in platforms:
    rect(x,1300,460,144,'#f0f8f6','#bfddd7',13)
    text(x+20,1320,title,29,bold=True,max_width=420)
    text(x+20,1366,sub,24,COL['teal'],max_width=420)
    text(x+20,1406,tool,23,COL['muted'],max_width=420)
text(95,1500,'本机设备边界；原始工具与传输细节不向上泄漏为业务决策',27,COL['muted'])
text(95,1545,'首片：iOS + fake 多端；随后第二真实平台。真机 / 云 / 私有远控不在首期。',25,COL['muted'])

# Right rail: proposal, identities, evidence/outcomes and projections.
panel(1620,180,520,177,'Agent 自主  /  模型提议','#fff8eb','#ecd7af')
lines(1648,241,['Agent 自选 A / B；模型提供候选','两路径不绕过 Core 安全语义'],24,COL['amber'],gap=38,max_width=464)
arrow([(1620,310),(1590,310),(1590,490),(1560,490)],COL['amber'],True)

panel(1620,395,520,318,'核心对象  ·  权威归属')
lines(1648,460,['SessionContext  →  可选目标绑定','Operation  →  单点，不强制 Run','Run  →  高级流程聚合','Step / Attempt  →  意图 / 实际发送','Observation  →  带失效边界的快照'],25,gap=42,max_width=464)
text(1648,683,'上下文可复用；执行结果不可混用',23,COL['muted'],max_width=464)

panel(1620,770,520,377,'Journal / Evidence / Outcome','#eef8f6','#bdded6')
lines(1648,835,['事件追加 · 脱敏 artifacts · manifest','四维结果，不能压成一个 ok：'],25,COL['muted'],gap=40,max_width=464)
lines(1648,927,['Execution       提交 / 交付未知','Verification    通过 / 失败 / 不确定','Recovery        完成 / 部分 / 人工','Evidence        完整 / 部分 / 不可用'],25,gap=39,max_width=464)
text(1648,1106,'单点事实 ≠ 整体业务通过',25,COL['teal'],True,max_width=464)
arrow([(1560,981),(1620,981)],COL['teal'])

panel(1620,1210,520,202,'Web / Wails  ·  只读投影')
lines(1648,1275,['Run 状态 / 观察 / 证据 timeline','展示为什么成功、失败或不确定','不持有业务策略、写操作与重试'],24,COL['muted'],gap=37,max_width=464)
arrow([(1880,1147),(1880,1210)],COL['teal'])

panel(1620,1460,520,178,'跨端 Conformance','#fff8eb','#ecd7af')
lines(1648,1526,['同一语义 fixtures / 同一裁决标准','逐端验证效果、限制与错误边界'],24,COL['amber'],gap=38,max_width=464)
arrow([(1620,1570),(1590,1570),(1590,1380),(1560,1380)],COL['amber'],True)

# Migration principle and invariants.
panel(60,1655,2080,199,'双路径并存：消融重复执行判断，不消融 agent 自由编排能力')
for x,title,sub in [(94,'聚合','高级流程用 Run；单点独立 Operation'),(782,'封装','两路径共用 Core 与多端语义'),(1470,'消融','去掉重复 dispatch / verify，不禁手动组合')]:
    text(x,1726,title,31,COL['blue'],True)
    text(x,1778,sub,26,COL['muted'],max_width=620)
text(62,1885,'硬边界：ACK ≠ 业务成功  ·  未知交付不盲重发  ·  不静默降级  ·  仅清理自有资源  ·  不承诺外部 GUI 排他',25,COL['muted'])
svg.append('</svg>')
PNG.parent.mkdir(parents=True,exist_ok=True)
assert not PNG.exists() and not SVG.exists(), 'Existing diagrams must be read/reviewed before replacement.'
SVG.write_text('\n'.join(svg)+'\n',encoding='utf-8')
im.save(PNG)
print(f'Created PNG {PNG.relative_to(ROOT)}: {W}x{H}')
print(f'Created editable SVG {SVG.name}')
