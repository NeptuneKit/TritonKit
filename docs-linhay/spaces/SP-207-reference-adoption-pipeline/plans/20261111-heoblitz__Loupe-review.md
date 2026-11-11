# Loupe 2026-11-11 固定增量评估

## Requested / Observed

base `180c60584867500b93b43ca6c8b556995bf8be7b` → head `1b6c7f0fa5f5ed2bd7885d404f85bcebd5ff0d93`，actual main `607410fb3d44bfe02274c13822170c3015c63a99`。2提交、10路径、18全文版本，无排除；提交分页到base、每parent完整树无truncated、blob hash核验。旧archive已不存在，此处全部为当前固定SHA重取副本，不声称旧raw已恢复。

## Evidence / Gap

[增量](https://github.com/heoblitz/Loupe/compare/180c60584867500b93b43ca6c8b556995bf8be7b...1b6c7f0fa5f5ed2bd7885d404f85bcebd5ff0d93)包含v0.6.0 bottle metadata及后续公开发布安全/Simulator CI retry修复。发布workflow从draft上传改为要求匹配public Release、非clobber上传、匿名curl下载核SHA之后提交Formula；测试含draft/tag错、404/坏字节/成功。脚本retry对所有inventory非零/timeout重试3次，每次120s及5s等待，只有attempt预算没有统一总deadline，不适合直接扩充Triton严格暂态白名单。现有SP221有同target/command严格诊断和总预算，保持该边界。

实际main update-homebrew-tap.yml以GH_TOKEN认证下载checksum，随即渲染/clone/push tap；没有isDraft/tag检查，也无发布前匿名arm64归档SHA核验。release.yml允许已有Release直接upload（可能为draft）。release.sh的brew fetch在tap流程之后，无法阻止先发布不可公开下载的URL。仅用grep检查workflow不证明失败时没有tap写入。

## Adopt / BDD与文件面

采用发布前公开资产完整性门禁：精确tag、public非draft、匿名下载arm64归档、manifest SHA一致均通过后才进入tap写入。draft/tag不符、HTTP404、下载超时/不完整、SHA不符均须fixture证明拒绝且无tap git动作；有效公开包允许继续。写入面限update-homebrew-tap.yml、独立最小校验helper与fixture、verify-release-automation接线及对应space文档。主控在main串行实现；本审阅未改产品、未发版或push。不要求模仿bottle格式、不移植injector、不恢复已停止的Intel发行。

## Release / License / Remaining risk

当前最新非draft v0.6.0完整notes已读：Simulator Web可见采样、DEVELOPER_DIR、SwiftUI/Xcode兼容、DTUHID及DeviceHub输入；这些notes含base前已交付DTUHID，不重复采用。LICENSE全文hash `0d7ebd755456885dba28523a5c468e59d06a26c8df2b896938632c9322c9e7e3`，人工MIT与API NOASSERTION分开保留。未下载发布二进制、执行上游、依赖或设备；public门禁当前缺口为源码静态事实，未验证线上曾发生draft泄漏或真实资产损坏。
