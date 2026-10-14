# Workspace config 私有存储

影响层：CLI host-defaults / host-targets 两个现有配置入口。无格式升级、无新配置 migration ledger；保留 JSON 模型和现有命令面。

## BDD 与实现

- `.triton`、workspace 祖先及最终文件含 symlink 时拒绝；所有目录逐级 openat nofollow，目录 owner 检查后通过描述符 chmod 0700；配置 regular-only/nlink=1/owner 当前用户，0600，最多 1 MiB。
- 缺失只读 load 返回 nil/empty，不建目录；路径不接受 caller 拼接任意 filename，固定两个白名单名字。
- 写入先验证新模型，再锁定 managed 目录，读并验证已有配置。坏 JSON/过大/非法旧配置不覆盖。alias schema只接受已知1/2，缺版本保持legacy1；future版本拒绝读和覆盖，原字节不变。
- 有效旧配置覆盖前先在 private `config-backups/` 保存 exact 原字节 raw backup（UUID 唯一、0600、原子）。相同字节无需备份/写入。发布前复核目录身份、最终 inode 和原字节；stage fsync 后 renameat 再目录 fsync。
- publication 注入失败发生在备份完成后、替换前，保持旧配置。无需无端格式迁移，也不把已有内存兼容读取写回为新版。

## 证据

- `.build/sp196-config-baseline.log`：旧 createDirectory + Data.atomic 在 `.triton` 为 symlink 时写出 workspace；基线反例成立。
- `.build/sp196-config-core.log`：新核心同源码独立编译执行通过 exact raw backup、注入失败原配置保留、坏旧配置拒绝覆盖、祖先 symlink 拒绝；future alias schema拒绝与原字节保留。
- `WorkspaceConfigStorageTests` 新增 fixtures 覆盖 private permissions/backup/坏旧数据/byte limit/symlink ancestor、managed、final、backup/readonly missing/非法名字/发布失败。
- 新 storage + 全部新 tests 的独立 swiftc typecheck（Xcode Testing framework/macros）通过，`.build/sp196-config-tests-typecheck.log` 0字节。该类型检查不替代tests运行。
- focused CLI 测试待主控统一门禁；未执行设备/服务/发布/用户验收。

## 边界与风险

- 所有路径组件拒绝 symlink；macOS `/var` 是系统 symlink，临时 fixtures 用 realpath 后的 `/private/var` canonical 路径。产品不自动 canonicalize 绕过用户路径检查。已核对旧 DeviceCrossPlatformTests（607/771/823/886/951）与 XcodeCommandTests（1346/1564）：它们先 chdir，再由wrapper读取 FileManager.currentDirectoryPath；本机实测返回 /private/var canonical，因此不需修改旧fixtures或放宽产品规则。
- 有效更新 raw backup 不自动清理、无 retention sweep；它包含私有 target 数据，保存在0700目录下0600文件。无法完成备份时不发布。
- 原子 publication 后目录 fsync 失败可能已替换 config，返回失败不意味着未产生写入；此 limitation 必须保持事实。
- 不宣称防御不遵循 flock 的同用户恶意瞬时竞态，也不把现有 JSON backwards compatibility 说成 migration 交付。

## 主控最终验证

主控最终完整CLI回归通过，相关安全/config suites无失败。
