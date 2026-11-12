## Context

2026-08-28 的 Urban / Recycle 拆分已经在运行：同一个 `MaterialClient.db`，内核 `MaterialClientDbContext` 与 `UrbanDbContext` / `RecycleDbContext` 分开，历史表分别是 `__EFMigrationsHistory_Kernel`、`_Urban`、`_Recycle`。产品初始迁移用 `CREATE TABLE IF NOT EXISTS` 接住已有表，设置用 `INSERT…SELECT` 且只在目标为空时复制，不 `DROP` 内核里的称重行。标准宿主不迁移 Urban / Recycle。多 Context 写同一库时使用 `ExistingConnection`。

Standard 与 SolidWaste 今天仍共用内核称重表和运单表。固废街道、类型、联单号、发货单位和独立净重标记在 `ExtraProperties`。把这些主表按模式拆走并删除内核行，超出当时已验证的「旧表留在原地、只移交产品专属表」范围，也会打断仍在读内核 `WeighingRecord` 的 Urban 上传。

## Goals / Non-Goals

**Goals:**

- SolidWaste 专属列有自己的表、Context 和迁移，加列不生成内核迁移。
- Standard 有自己的 Context 和迁移历史，供以后的 Standard 专属列使用。
- 已有称重、运单、附件关联原样留在内核表。
- 启动顺序与 Urban / Recycle 相同：先内核，再产品。

**Non-Goals:**

- 不把 `WeighingRecords` / `Waybills` 拆成两套物理表，也不删除其中的行。
- 不拆成多个 SQLite 文件，不用 `ReplaceDbContext`。
- 不改 Urban / Recycle 的扩展表和宿主迁移顺序。
- 不在本变更删除 `ExtraProperties` 里已有的固废键。现有同步读取仍可读这些键。

## Decisions

### 1. 复用同库产品 Context，不复用「切走主表」

**选择**：新增 `MaterialClient.Common.SolidWaste` 与 `MaterialClient.Common.Standard`。固废字段进入 `SolidWasteWaybillExtension`、`SolidWasteWeighingExtension`。关联只用 `WaybillId` / `WeighingRecordId`。内核主表继续服务 Standard、SolidWaste、Urban、Recycle。

**放弃**：按 `WeighingMode` 把主表行复制到新产品表再删除内核行。Urban / Recycle 没有这样做；Urban 仍用内核称重行加逻辑 Id 扩展表。

### 2. 历史数据只复制，不搬迁

**选择**：产品迁移 `CREATE TABLE IF NOT EXISTS`。标准宿主在 SolidWaste 迁移之后，把 `WeighingMode.SolidWaste` 行上已有的固废键补进扩展表；目标已有该逻辑 Id 时不覆盖。内核行和 `ExtraProperties` 保留。

**放弃**：用当前运行模式过滤要迁移的行。分类以行上的 `WeighingMode` 为准。

### 3. 宿主边界与 Urban / Recycle 对称

**选择**：标准宿主 `DependsOn` 两个新产品模块，顺序为内核、`StandardDbContext`、`SolidWasteDbContext`。Urban 宿主与 Recycle 宿主不引用这两个项目。历史表名为 `__EFMigrationsHistory_Standard` 与 `__EFMigrationsHistory_SolidWaste`。同一 UnitOfWork 内后续 Context 使用 `ExistingConnection`。

### 4. 写入走产品仓储，读取兼容现有键

**选择**：标准宿主上的固废保存，在写内核实体之后 upsert 扩展行。扩展实体用自身方法改字段。导出优先读扩展表；没有扩展行时仍读 `ExtraProperties`。Urban / Recycle 宿主继续使用 Common 里的空实现，不访问 SolidWaste 表。

## Risks / Trade-offs

- [扩展表与 ExtraProperties 短时间双写] → 扩展表是固废列的迁移 owner；键先留着，避免同步和界面的同步读取在这一变更里全部改掉。
- [补数中断后再启动] → 按逻辑 Id 判断已存在则跳过，不删除内核行。
- [两个 Context 抢同一 SQLite 写锁] → 沿用已归档的 `ExistingConnection`，产品迁移放在内核迁移完成之后。
- [Standard 暂时没有专属业务表] → 先建立 Context 和空的初始迁移，避免以后把 Standard 专属列加回内核。

## Migration Plan

1. 增加两个产品项目和 sln 条目。SolidWaste 模型只含两张扩展表。
2. SolidWaste 初始迁移创建扩展表（`IF NOT EXISTS`）和逻辑 Id 唯一索引。不修改 `WeighingRecords`、`Waybills`。
3. Standard 初始迁移不建业务表，只占用该 Context 的迁移历史。
4. 标准宿主：`KernelDatabaseMigrator`，然后 Standard，然后 SolidWaste，然后按 `WeighingMode.SolidWaste` 补扩展行。
5. 回退：不写会删扩展数据的 Down。失败时用升级前的数据库副本换回旧程序。

## Open Questions

- 下一次 Standard 专属列出现时，直接加在 `StandardDbContext`，不再改内核称重表。
