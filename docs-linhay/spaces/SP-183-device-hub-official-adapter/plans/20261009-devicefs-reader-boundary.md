# DeviceFS descriptor安全reader（内部基础，非公开CLI已支持）

## 实际发现

任务自有Simulator的Triton mountpoint→no-follow root浅metadata probe成功，finally恢复Shutdown、全体names/state不变。实际根是AppDataContainers/AppGroupContainers/root及本地化项，未出现直接DiagnosticReports。不得猜crashLogs=root或任意递归查找；域映射需另行metadata证据。原只读设计subagent失败无closing，不计审查通过。

## BDD / TDD

Given caller拥有已绑定设备的词法标准绝对根及明确允许的relative segments，When内部reader枚举该目录，Then从/逐组件openat(O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC)，每层用fd而非拼接路径，拒绝根/父层/子层symlink及dot/traversal/empty/control/非法UTF8，深度<=64、总path UTF8<=16384；leaf仅fstatat(AT_SYMLINK_NOFOLLOW)，不打开content/不follow symlink、不递归。maxEntries 1...10000，读到第max+1项即reject不partial，不读后续metadata；readdir errno及fstatat失败均fail-closed。未知文件kind明确other，不把目录size当content size，不把mode当授权。private model不Encodable，公开隐私在未来runtime单独实现。max budget为entries及路径接受限，不声称FUSE操作可中断或远端传输/磁盘硬限；目录并发变化不保证原子snapshot，拒绝可观察到的消失/换inode，不伪造一致快照。

Given临时私有测试目录，When根/parent/relative symlink、dangling leaf、file代替directory、budget/invalid path及UTF8测试，Then证明no-follow边界和无内容读取；包含symlink leaf可报告symbolic-link本身，不读目标。fixtures仅task-owned tiny目录，无DeviceFS写或business设备动作。

## Darwin variable-length record边界

[Apple Libc readdir源码](https://raw.githubusercontent.com/apple-oss-distributions/Libc/main/gen/FreeBSD/readdir.c)显示返回buffer内部变长d_reclen record，不能先将完整d_name tuple值拷贝再prefix(d_namlen)。需先校验header/name offset/count/record容纳count+NUL，再从raw pointer指定字节复制；固定tuple size仅作静态capacity上界，不从record加载整tuple。测试declared record不足、NUL缺失、合法短record与guard-page末尾的短record，不以fixture无crash推测原实现绝对安全。纯词法path validator精确计算nil-relative无需额外分隔符，避免16384byte边界off-by-one。fdopendir使用F_DUPFD_CLOEXEC避免dup到stdio之间的潜在exec继承窗口。

## 未完成

第五批reader阶段尚无publicCLI；第六批已实现并实际owned验收[显式fs list mount-root限定切片](./20261009-devicefs-list-verification.json)：fresh fileJSON/currentUUID标准根绑定、同finalFD owner检查、公开privacyDTO/schema，实际metadata/root-only listing。仍不是domain导航完整；custom mount roots、temporary、App域identifier访问、domain policy、recursive/pagination另行显式契约，不自动files失败fallback，也不接受agent任意hostpath。本文件内部reader fixtures不独立构成DeviceFS public完成证据，完整目标继续。
