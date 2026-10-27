# MobAI-App/simslim 2026-10-27 增量审阅

结论：adopt。files-recents/searchd is a concrete gap in existing resource doctor catalog and search downside; disk-cleanup bundle preservation has no equivalent local traversal, observe. SP-221 bounded read retry is already delivered; do not re-dispatch.

实际 main `cfda992467fc1ed19ef0c577577c313d79314069`；当日 compare 2 commits，7 个固定SHA白名单文本；compare和逐commit文件分页读完，Release notes与固定许可全文/hash已核实。只读源码评估，未执行上游、设备、依赖或Git写操作。

## files-recents diagnostic — adopt

features array has 24 entries without files-recents; search downside omits Files/document picker Recents. Existing spotlight requirement includes searchtoold as well and cannot express exact searchd-only requirement.

- Given searchd disabled, resource doctor --requires files-recents reports ok=false and disabledLabels=[com.apple.searchd].
- Given searchd enabled and searchtoold disabled, files-recents remains healthy; requirement must not broaden to spotlight.
- features lists files-recents with exactly searchd; unknown requirement still fails; search profile warns about Files/document picker Recents.

验收：Focused catalog/inspection/parser-schema tests, full CLI --no-parallel and docs gates; preserve service-overrides-only verification boundary, no claim UI has recovered.

## installed bundle cleanup guard — observe

No matching disk-plan/disk-cleanup or recursive cache deletion implementation in actualmain; do not add destructive product surface merely to port upstream fix.

## launchd retry — covered

SP-221 state runtime and retry tests present on actualmain; v0.13.0 release mentions already reviewed live services without new delta.

许可：MIT，hash `8b65667572b02a584c03c2977372eeb5fe8de0e228211b6f83033c458cc10b4e`；复用保留许可与归属，Apache还需NOTICE/修改标记；不把源码许可外推上游二进制。

取证清单与本地文件面见 review.json。仅生成review/取证，未改索引、memory或checkpoint；无额外经验规则，沿用既有安全文本白名单与增量/累计分离规则。
