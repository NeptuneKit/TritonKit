# SP-285 — Android wm size 有效尺寸选择

## 问题与边界

11月12日跟进 [Mobile MCP 1.0.17](https://github.com/mobile-next/mobile-mcp/releases/tag/1.0.17) 的独立 mobilecli 横屏修复时，本地主线复核发现另一个可独立证明的解析缺陷：`TKAndroidWMSizeParser` 返回任意首个 WxH，正常 Physical 在前、Override 在后的输出会误选物理尺寸；错误诊断中的 WxH 也可能被当成功。

官方输出依据：[AOSP固定WindowManagerShellCommand](https://android.googlesource.com/platform/frameworks/base/+/167b01edf8258a5846838a13b4051b2233bc82af/services/core/java/com/android/server/wm/WindowManagerShellCommand.java#161)先打印initial Physical，baseSize不同时再打印Override。只用其输出合同证明选择顺序，没有引入或运行该代码。

实际基线main `0ec972e6151eb27372b3bdf5aa940940c56c30b0`。影响shared parser与既有只读 `/web/geometry` 尺寸显示；该DTO未被当前页面用来发送坐标动作，不能称已证明tap错位。旋转仍观察；不新增Web写控制面、设备动作或display选择协议。

来源机制仅作为审查线索，独立实现现有命令的有效尺寸优先级；不复制 mobilecli FSL-1.1-ALv2 实现。Mobile MCP自身Apache-2.0与外部backend许可分开。

## BDD

- Given Physical与Override任一顺序，When读取尺寸，Then选择合法Override；无Override时选择合法Physical。
- Given错误诊断中包含WxH，When没有标准尺寸行，Then返回nil，由既有调用者报失败。
- Given显式尺寸行无效、溢出或同类重复，Then返回nil，不回退Physical伪造有效Override，也不猜测多份显示输出归属。
- Given合法尺寸，When构造现有geometry，Thenbounds准确；该值不等于当前旋转截图尺寸或业务动作成功。

## 验收

在当前main串行TDD实施，保留SP281等WIP。证据写入plans；真实Android/ADB/截图旋转未执行，测试仅离线解析与既有DTO链路。

已完成失败测试→最小实现→独立审查与离线回归；[验收明细](./plans/20261112-validation.md)。main提交与提交后门禁收口中。
