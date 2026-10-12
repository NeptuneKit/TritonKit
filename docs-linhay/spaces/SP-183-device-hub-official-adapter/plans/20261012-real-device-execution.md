# 真机写入验收（2026-10-12）

用户本轮明确授权配对/解除配对、诊断采集、App 安装启动。固定唯一在线 USB iPhone，另一在线网络设备不执行写入。原始证据私有保存到保留 worktree `.triton/real-execution-20261012/`；诊断含设备及部分主机 CoreDevice 日志，不公开内容。

BDD：管理动作必须显式策略及审计，精确身份、原生file JSON与独立后置状态；诊断使用私有新ZIP、权限/防覆盖/大小检查；App只使用Triton专用fixture，安装后查询、启动后核对进程；解除配对后恢复配对，失败/未知先查询，不盲重试。

首次pair实际失败：native timeout 30.0被当前SDK整数解析拒绝，无native JSON/log；独立只读list探针重现exit64，details后置查询成功。先增加失败测试，修复原生命令整数秒序列化（向上取整），保留host精确deadline，再重新评估动作。

修复后20个管理测试通过；真实pair执行成功，nativeResultVerified与pairingStateVerified均true，paired后置通过。Triton xcode build签名真机fixture成功；精确bundle此前不存在，安装与app info成功；launch返回device_locked，已请求用户解锁，不绕过设备保护。诊断已显式执行，结果待完成。

## 实际动作结果

- pair 成功，原生 file JSON 与独立 paired 后置均验证。
- diagnose 已真实采集并完成原生成功结果，生成344410367字节的私有ZIP（0600）。超过配置的268435456字节验收发布上限，返回partial / device_administration_limit_exceeded；目标归档未发布。保留原生归档，不重采、不放宽预算、不声称完整内容或成功发布。
- unpair 成功，原生结果与独立 unpaired 后置均验证。随后同一USB设备从CoreDevice清单消失；恢复pair命令在发现阶段target_not_found，未发送动作。已要求用户解锁、拔插同一设备并接受系统信任提示，未换目标、未绕过fresh identity门禁。
- 专用fixture此前未安装；签名真机构建、安装和app info通过。launch被device_locked阻塞，App仍安装在设备，未声称成功启动或业务ready。

[机器可读结果](20261012-real-device-execution.json)。恢复配对与启动仍待用户设备操作；另一台网络iPhone未执行写入。
