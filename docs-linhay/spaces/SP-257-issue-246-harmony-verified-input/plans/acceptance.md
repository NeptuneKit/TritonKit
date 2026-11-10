# #246 实际设备验收与当前交付边界

2026-11-02：本候选从本次合并/发布范围排除。用户要求只做agent可独立完成验证的需求；成功文本输入路径仍依赖新HVD系统IME许可交互，未接受该条款，不交给用户人工处理，不阻塞#245独立交付。保留全部候选及证据，不能写成通过或完整issue解决。

## 真实环境与命令

自有 `TritonKit_SP257_Input`，HarmonyOS6.0.2(22)，本地镜像；目标127.0.0.1:10103。旧Codex Test Phone已不存在。先保存Triton discovery/schema/launch失败，因Triton无create入口，使用官方Emulator CLI创建新实例，再通过Triton启动、wait-ready、安装/启动自有com.tritonkit.sp257.inputprobe。无私有项目改动。

标准fixture HAP由 `triton build harmony`构建，0错误/0警告；安装/启动、真实dump读回通过。首次normal输入在聚焦时遇到系统IME许可弹窗：receipt `harmony_input_focus_unknown`、`submission=not-sent`，没有文本发送。取消后仍需模式许可，已选择退出应用，未接受许可。

按本机公开SDK声明，对自有TextArea采用 `enableKeyboardOnFocus(false)`，重新构建/安装后仍出现相同许可窗与not-sent。该尝试是真实失败，不能用单测、关闭键盘选项或输入提交回执替代成功字段验收。没有改系统权限/guard、没有接受条款、没有切换后端或重放未知文本输入。

## 已验证与未验证

- 实测negative：duplicate、disabled、password分别返回ambiguous/not_editable/secure_unsupported，均not-sent；独立App状态始终changes=0。
- 真实TextArea空串/focused/visible等字段为字符串；空Password TextInput没有password/isPassword/inputType标志，必须保持安全类型未知拒绝，不能由空text推断非密码。
- normal完整值、单次变更计数、Unicode/符号输入、delayed settle、reject mismatch：未完成真实验收。合成runtime测试覆盖不替代现场通过。
- 实测二进制SHA256 `d255cabf84bb0c3ec8663976b9fca9b1d26bdaca3756e28df5f106913ede4bf3`；后续枚举timeout修订仅有本地测试时，必须分别报告，不能把上述旧binary证据迁移为新candidate全面通过。

原始证据保留在自动任务本轮scan目录 `2026-11-02T08-26-30.072211+00-00`，包括两次normal失败、三个negative的receipt/raw前后树与App计数。真实验收脚本：[accept-harmony-input.py](accept-harmony-input.py)。原始dump只用于自有fixture，未上传公开制品。

## 运行接替

自有HVD通过 `triton device stop --skip-launchd --confirm` 停止，保留设备、fixture和证据；不清除其他任务资源。只有已有可自动维护、无需人工许可介入且能证明真实输入的环境出现后，才重新评估本候选；当前不安排人工步骤、不发布未验功能、不关闭issue。
