# Revyl CLI 2026-11-01 增量审阅

裁决 observe，无新增采用。允许文本增量已读完整，总体仍 partial。

## 固定来源与安全范围

[base 34a9587](https://github.com/RevylAI/revyl-cli/tree/34a9587752f06cdc41cfce7acd46d408c8f799e8) → [head 13462d3](https://github.com/RevylAI/revyl-cli/tree/13462d32e2ff87ee7ee1feff418fdcb7e18c2f57)，官方分页commits首100项内到base，4提交全部实际父边、5棵recursive tree均不截断。先按CLI/API/docs/打包用途和文本白名单筛选，再取19个允许文本路径所有中间版本，共43 blob，Git blob SHA校验通过。24条路径含4个pyc及无扩展VERSION，这5条不取内容。没有下载含patch的完整compare/commit响应。

脚本从昨日复制后明确替换base/head，目录来自自身`__file__`，无历史日期硬编码写入。`commits-1.json`、tree、`path-screening.json`、blob原JSON、`texts/`、diff和schema结构diff可复核。

官方许可证全文仍404，README/PyPI声称MIT不能代替固定全文或hash；历史hosted backend/分发来源缺口无恢复证据。最新官方Release仍[v0.1.204](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.204)，notes全文保存，只是安装/skill/checksum说明；head版本0.1.208与发布版本分开。未下载release二进制。

## 主要机制与裁决

1. 新`cmd/revyl/session_download.go`（563行）获取设备session或execution云报告的video timeline，保存脱离短期signed URL的timeline.json；按后端提供的每action首帧offset、padding窗口顺序用ffmpeg切片，可选full video或no-clips。404仅在符合session→execution语义时回退；computer unsupported与路由缺失独立报错。没有视频、无时间戳、越视频边界均保留不生成片段的事实。
2. 切片采用关键帧前解码、copyts/start_at_zero、fps补静态帧后trim和重置PTS；ffmpeg exit0仍要求progress frame>0，空片删除。进程timeout按窗口长度增加且WaitDelay5秒，错误尾600字节。下载沿用临时文件原子rename，进度在无Content-Length时只显示bytes，不伪造百分比；签名URL从本地timeline排除。doctor增加ffmpeg缺失warning/no-clips替代。仅阅读，不运行ffmpeg或安装。
3. 实际main `CLIDeviceRecordingModels.swift`只有会话开始/结束、actualDuration/sampleCount及target身份；`CLITestRecorderModels.swift`是独立事件/录制manifest，未提供与视频首帧同源的action offset。它们不等价上游服务器已经对齐的video timeline。直接按墙钟剪片会伪造同步，复制客户端也无法生成可信偏移，故本轮保持观察：未来只有本机同源时间轴需求和测量来源成立后才可独立设计，不能据此接入Revyl云报告或强加ffmpeg依赖。
4. SP-200既有录制已用真实video samples/发布成功判completed；SP-192/196的视觉/证据机制保持unknown与业务验证分离。上游frame count拒绝空片与本机既有录制空样本拒绝方向一致，不再重复派发。`local-main/`固定保存对应源码和三个space，`adoption-snapshot.json`用于去重。
5. 其他增量：org-runtime非UUID user身份认证测试、AuthInfo is_runtime_principal与computer实际build_id DTO；computer没有能覆盖整生命周期host时runtime_unavailable且不创建；iframe无ticket登录失败显示Open in browser/Try again、过期原地退出。这些仅托管身份、宿主资源和frame登录机制，Triton loopback产品没有对应新增缺口。report状态enum和generic字符串解引用只是DTO兼容。schema全部差异见`schema-diffs.json`/`generated-diffs.txt`。uv.lock只有revyl自身版本同步，未变第三方依赖。

## 验收边界与沉淀

真实比较基线main `4b4b6a841446243c3fb76af800483cda65bbc738`，当前仓库main且启动时工作区干净；不写result/docs/state/Git、不执行第三方代码、依赖、构建或设备。没有实现切片，不把上游测试/源码阅读当本地运行通过。沿用既有请求前筛选和partial来源规则，无新增流程经验；正式memory/日报由主控统一回写。
