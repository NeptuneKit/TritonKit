# tddworks/baguette 2026-10-27 增量审阅

结论：observe。Software keyboard toggle is a concrete optional host-input gap, but upstream private legacy HID button 1008 is not validated under Triton isolated helper/ownership contract. Keep as bounded candidate; do not treat SP-218 tap/swipe or SP-219 recording as keyboard proof, and do not import Baguette binary.

实际 main `cfda992467fc1ed19ef0c577577c313d79314069`；当日 compare 4 commits，14 个固定SHA白名单文本；compare和逐commit文件分页读完，Release notes与固定许可全文/hash已核实。只读源码评估，未执行上游、设备、依赖或Git写操作。

今日 delta 完整不等于累计完整：旧 binary/source provenance 与 identity/certificate omissions 保留；未重新获取这些内容，checkpoint 不推进。

## software keyboard toggle — observe

Current CLIHostNativeHIDRuntime/helper accepts only tap/swipe, sim type explicitly unsupported; no software-keyboard action contract. Baguette maps DeviceButton.softwareKeyboard to legacy HID (1008,0x33), exposes press parsing and fake acceptance/rejection tests; those do not prove guest delivery in Triton.

- Given supported booted portrait simulator and focused text field, explicit toggle submits one down/up pair; observe keyboard visibility before and after, never infer success from helper acknowledgment.
- Given Device Hub attachment, unknown/Resizable/multiple display, helper failure or changed surface, fail closed and do not auto replay toggle.
- Unknown button or unavailable ABI returns one stable unsupported envelope; no external binary/override and no implicit text insertion.

验收：Before adoption settle high-level act press routing and isolated helper ABI; test parse/schema/down-up/rejection/deadline and run explicitly authorized dedicated-Simulator keyboard appearance/disappearance proof. No device work performed today.

## existing input/resize tracks — covered

SP-218 native ordinary HID/ownership and SP-219 ordinary→Resize→ordinary recording delivered; neither implements keyboard toggle. Their current real evidence is retained; no redundant adoption.

许可：Apache-2.0，hash `0509ebb2d8d399fb183d1973d3f6ad585e209ca4c2c42a90f3c22c0f32c1ab3e`；复用保留许可与归属，Apache还需NOTICE/修改标记；不把源码许可外推上游二进制。

取证清单与本地文件面见 review.json。仅生成review/取证，未改索引、memory或checkpoint；无额外经验规则，沿用既有安全文本白名单与增量/累计分离规则。
