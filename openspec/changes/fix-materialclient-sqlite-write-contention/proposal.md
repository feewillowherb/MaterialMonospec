## Why

固废客户端在称重判稳后偶发 SQLite 写锁错误，导致称重记录未落库。称重恢复、自动匹配和轮询可以同时访问同一个数据库文件。

## What Changes

- 对固废客户端同库业务写入按数据库文件串行调度。
- 将恢复完成和失败状态写入纳入调用方管理的短 UoW，去掉辅助方法自行开启的独立 UoW。
- 将持久化称重收尾恢复限定为产品显式启用的能力。SolidWaste 和 Standard 不启动扫描、不写恢复状态，Urban 和 Recycle 保持现有启用行为。
- 确保内核运单和固废扩展的原子写入共用连接及事务。

## Capabilities

### New Capabilities

- `materialclient-sqlite-write-serialization`：约束固废客户端的本地称重、恢复、匹配和轮询写入。

### Modified Capabilities

- `weighing-cycle-recovery`：只对显式启用的产品持久化收尾恢复。

## Impact

- MaterialClient 共享称重服务和 SolidWaste 主机的 UoW 与 SQLite 配置。
- 外部锁的合成证据：`fev-sqlite-write-contention-repro/2026-11-24T141850`，结果 `pass`。现场锁持有者仍未知。
