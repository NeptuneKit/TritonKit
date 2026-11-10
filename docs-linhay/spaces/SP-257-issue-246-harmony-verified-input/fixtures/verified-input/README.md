# Verified native input fixture

自有离线 ArkUI API 22 工程，bundle `com.tritonkit.sp257.inputprobe`。仅供独占的 SP257 HVD 验收，不连接网络、不包含凭据或签名。资源使用小型 SVG，不携带旧 ArkWeb payload。

- `mode-normal`：空 TextArea `id:editor`，可观察 `probe-status` 的 onChange 次数、`probe-observed` 和 `probe-value`。
- `mode-duplicate`：两个相同 id，必须在 tap/send 前拒绝。
- `mode-disabled`：禁用 TextArea，必须在发送前拒绝。
- `mode-password`：密码 TextInput，必须 unsupported，不能发送或输出实际值。
- `mode-delayed`：输入后 600 ms 把完整值改为 `<input>-settled`；expected 使用完整 settled 值，检查只读轮询。
- `mode-reject`：onChange 后值改为 `REJECTED`，验证 mismatch 且不重放。

按钮仅供测试切换场景；CLI 必须先 Triton-first 记录 status/doctor/capabilities/schema/plan。构建、安装和设备操作由主控串行执行。fixture 本身尚待真实编译与运行验收，源文件不是通过证据。

验收环境补充：全新HVD的系统输入法首次聚焦要求许可确认，已取消并退出输入法，保留focus_unknown/not-sent原始证据。此自有fixture通过公开ArkUI `TextArea.enableKeyboardOnFocus(false)`不请求软键盘；输入仍须走真实Triton/uitest并独立读回，不通过App自写值替代输入。该设置不证明系统IME首次启用流程或其他App键盘配置通过。
