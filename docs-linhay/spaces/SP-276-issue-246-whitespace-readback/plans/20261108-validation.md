# SP276 验证

基线远端main bd0b1dbd。旧代码root新增3测试记录13断言失败；CLI新增2测试记录9断言失败，RED日志留在本机archives/SP276，不上传私有内容。

最小修复：仅text/originalText改为contentString，非empty字符串原样；empty继续nil；metadata不变。根包全部通过（297 shared Swift Testing/43 suites及129 runtime Swift Testing/26 suites；XCTest见原日志），完整CLI 1791 Swift Testing/193 suites及XCTest通过。后补find直接回归，再运行新增focused suite；测试数不与完整回归相加。

独立审阅无P1/P2；见review。文档门禁首次因SP276总览显示名不是完整key被拒，修正为规范链接后重跑；此前失败不计通过。

边界：转换fixture可完整证明本切片；HDC空白发送、人工IME许可、clear、原私有App业务成功均未证明。#246整体不标完成、不关闭。


真实CLI入口（fake HDC，只提供layout JSON，无设备）复验：安装版0.2.41对三组空白均失败（0/3），候选编译CLI 3/3通过。可复跑脚本[whitespace-cli-fixture.py](whitespace-cli-fixture.py)，输出包含二进制绝对路径；安装后必须再次运行。脚本不绕过设备权限或断言真实IME。

补齐v0.2.41历史发布浏览器缺口：从/tmp无root覆盖启动安装包34129，plan packaged/readonly；Ego真实浏览器显示只读工作台，HTML/JS/CSS200，console无error，离线无设备状态。此项不证明三端实时流。独占服务待本轮验收后停止，共享19421未操作。
