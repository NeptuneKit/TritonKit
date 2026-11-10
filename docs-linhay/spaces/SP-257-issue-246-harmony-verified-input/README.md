# SP-257-issue-246-harmony-verified-input

状态：候选保留，本轮合并/发布排除。关联GitHub #246，影响CLI Harmony host act.type与只读回读；默认transport-only路径兼容。

## BDD与验收

- opt-in稳定id selector解析唯一editable字段，未聚焦时最多一次tap，读取focus证明后才send一次text；unknown/malformed/ambiguous不发送。
- submitted与observed状态分离，显式expected full value精确比较，bounded只读轮询，发送未知不重放/换backend。
- secure/masked字段不发送并typed unsupported，日志/错误不泄漏值；空串/空白精确保存。
- 注入失败测试与正常/延迟/超时/歧义/焦点失败回归；自有公开ArkUI fixture真实验收，禁止操作其他任务设备或原私有App。
- 仅交付agent可独立完成并验证的场景；环境需人工时排除该部分并保存未验证事实，不阻塞其他工作。

## 归属

基线origin/main9b3dd908。feat/SP-257-issue-246-harmony-verified-input；桌面工具创建隔离路径/Users/linhey/.codex/worktrees/sp-257-issue-246-harmony-verified-input/TritonKit。SP252–256仅编号/需求登记，不混入其他产品/WIP；主控负责整合与发布，issue不自动关闭。

## 候选实现

CLI独立 raw decoder、一次性 verified-input runtime、TypeText显式opt-in和schema已准备；规则见[契约](plans/verified-input-contract.md)，自有[fixture](fixtures/verified-input/README.md)。共享SDK保持不变。本地首轮18项focused与7组实际CLI失败JSON验收通过，随后枚举timeout缺陷以2项真实RED收口，当前20项/5 suites通过；一次超时掩盖mismatch的真实RED→GREEN已记录在契约。自有fixture编译已由主控通过；真实normal场景即使关闭键盘请求仍弹出输入法许可，已取消且未接受，未得到独立文本输入验收。按2026-11-02用户要求从本轮合并/发布排除；保留候选和失败证据，不向用户安排人工步骤。仅收口已知局部枚举timeout归因缺陷及测试，不扩大功能。
