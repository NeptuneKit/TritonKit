# Skill 安装器永久回归

影响层：本机 skill 安装脚本的测试与打包门禁。子任务只修改 Python 测试和 `verify-skill-package.sh`，生产修复由主控负责；未触碰 Swift、设备、服务、提交或发布。

## 场景

原有 6 项回归保留：缺失包不覆盖旧安装/legacy、归档成员 traversal 拒绝、用户修改拒绝、dry-run 无写入、正常升级保留 backup/0600、destination root symlink 拒绝。

新增 7 项：

1. source archive 本身为 symlink 时拒绝，destination 不创建。
2. source archive 的父目录为 symlink 时拒绝。
3. destination 的父目录为 symlink 时拒绝，真实目录保持为空。
4. source 原始路径带 `child/../archive` 或 `symlink/../archive` 时拒绝，不能先 normalize 再验证。
5. destination 原始路径带 `child/../agent` 或 `symlink/../agent` 时拒绝。
6. 使用真实 `copytree` 先完成 staging，再注入 current 用户修改：install 报 conflict，用户字节保留、incoming stage 清理、无 backup，自己的 lock 释放。
7. 执行真实原子 exchange 后对 backup rename 注入失败：失败显式上抛；旧安装停留在 stage、原字节及 receipt 完整，不能被 finally cleanup 删除；新 current 同时保持完整，lock 释放。

故障注入只拦截确定的生产调用，断言实际注入次数，防止测试未命中窗口却假通过。原子 exchange 使用当前系统真实能力，不 mock 为成功。

## 发现与修复归属

检查生产发现 source archive 未验证 symlink、`os.path.abspath` 在拒绝 traversal 前折叠原始 `..` 两处漏洞，已报告主控。主控修复 `install-public-skills.py`；本子任务不放宽负例。首次回归执行时主控修复已经落盘，未单独保留这两漏洞的旧实现 red 日志。

主控明确授权在 `verify-skill-package.sh` 增加 explicit unittest gate；门禁在打包前调用 `python3 -m unittest discover`，只运行安装器测试，以 `PYTHONDONTWRITEBYTECODE=1` 避免检查生成缓存。

## 验证

2026-10-14：

- `python3 -m unittest discover -s docs-linhay/scripts/tests -p test_install_public_skills.py -v`：13 tests 全通过，日志 `.build/sp196-installer-python-tests.log`。
- `bash docs-linhay/scripts/verify-skill-package.sh`：新增 13 tests + 原有打包/安装验证全通过，日志 `.build/sp196-installer-package-validation.log`。
- `git diff --check`：通过。

结论为当前候选生产脚本、macOS Python 和原子目录交换环境下的本地实现/故障/打包验收。没有对用户真实 skill 目录执行安装，也没有对远端发布作判断。
