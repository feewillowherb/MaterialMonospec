# 06 · XiaoShanServe 已入库数据迁移至 UM

**状态**：**挂起**（2026-09-03）→ Intake [INT-007](../intake/2026-09/INT-007-xiaoshanserve-govsyncdata-migrate.md)（`parked_until=2026-09`，theme `xiaoshan-upload`）  
**目标**（消化时）：把 XiaoShanServe 本地库中**已经入库**的称重流水迁到 UrbanManagement，落为 `UrbanWeighingRecord`（+ 附件）。  
**非目标**：不恢复向 UM `GovSyncData` 双写；不把迁移脚本当长期业务 API；**不**并入当前在线 Legacy / INT-006 实现。

> **挂起说明**：本文件保留已拍板映射与约束，供日后 digest；**当前禁止**据此开 OpenSpec apply / 生产迁库。在线路径仍以 INT-006 + 本夹 00–05 为准。

## 一句话

源：`XiaoShan.db` 的 `Gov_SyncData`（及磁盘 `snapImages`）+ 必要的 `Gov_Project` 对照。  
宿：UM `UrbanWeighingRecords` / `AttachmentFiles` / join。  
映射逻辑应**复用**与 `LegacyGovSyncAppService` 相同的字段规则（[02](./02-字段映射与缺口.md)），批量入口单独（脚本 / 一次性 AppService / pipeline ingest），幂等可重跑。

## 源侧现状

| 项 | 路径 / 说明 |
|----|-------------|
| DB | `repos/Fdsoft.Weight.GovClient/FdSoft.MaterialSys.Gov.XiaoShanServe/XiaoShan.db`（现场多为同机绝对路径副本） |
| 流水表 | `Gov_SyncData` → 模型 `GovSyncData`（SqlSugar，`Id` int） |
| 项目表 | `Gov_Project`：`ProId` **string**、`BuildLicenseNo`、`FdBuildLicenseNo` |
| 图片 | `FilesPhysicalPath` + `snapImages` 中相对路径（如 `//TempUpload//{accessCode}\{ticks}_{i}.jpg`） |
| 同步态 | `SyncType` 0/1/2；`SyncNumber` 重试次数；已成功行若再出站会**双报政府** |

UM 内遗留实体 `GovSyncData` 为历史只读表，**迁移目标不是它**，而是 `UrbanWeighingRecord`。

## 字段映射（批处理）

与在线 Legacy 对齐，差异仅在「图从路径读」与「幂等键带旧 Id」：

| `Gov_SyncData` | `UrbanWeighingRecord` | 备注 |
|----------------|----------------------|------|
| `CarNo` | `PlateNumber` | |
| `CarColor` / `CarNoColor` / `CarType` | `VehicleColor` / `PlateColor` / `VehicleType` | |
| `DeviceId` | `DeviceId` | |
| `BuildLicenseNo` | `AccessCode` | 须能在 UM `GovProjects.AccessCode` 命中 |
| `siteType` | `SiteType` | `"1"`→Construction，`"2"`→Disposal |
| `goodsWeight` | `TotalWeight` | decimal kg；解析失败 → 拒迁或 0（需产品定） |
| `snapTime` | `WeighingTime` | 可复用 UM `GovSyncData.TryParseSnapTime` 同类逻辑 |
| `AddTime` | `CreationTime` | 尽量保留入库时间；若走 EF 常规 Insert 可能被覆盖 → 需 migration/SQL 或绕审计赋值策略 |
| `ProId` (string) | `ProId` (Guid) | **按 AccessCode 查 UM 项目**；勿直接 `Guid.Parse` 旧字符串除非已确认同形 |
| `ProName` | `ProName` | 优先 UM 项目名，缺则用源 |
| `SyncType` 0/1/2 | `SyncType` SyncStatus | 见下节「出站策略」 |
| `SyncNumber` | `RetryCount` | |
| `SyncTime` | `SyncTime` | |
| `sourceData` | （不落库） | **丢弃**；不写 `ExtraProperties`、不迁入实体列 |
| `Id` (int) | （不映射） | **丢弃**；UM `UrbanWeighingRecord.Id` **重新生成** Guid，不沿用源 int |
| `snapImages` 路径 | `AttachmentFile` + join | 读盘 → 复制/注册到 UM 存储根 |
| （派生） | `IngestSource` | **`Migrated`** |
| （派生） | `IsAnomaly` | 默认 false |
| （派生） | `ClientRecordId` | **全部 `Guid.Empty`（全 0）**；批迁不走客户端幂等语义 |

## `IngestSource`：建议第三值

在线 Legacy 与**批量迁移**应可区分：

```csharp
public enum UrbanWeighingIngestSource
{
    Modern = 0,
    Legacy = 1,   // 在线 /Api/Post
    Migrated = 2  // XiaoShanServe Gov_SyncData 批迁
}
```

- 更新 [05](./05-入站来源枚举.md) / 总览 D4：批迁写 `Migrated`。  
- 若坚持两值：批迁可写 `Legacy` + `ExtraProperties["migratedFrom"]="XiaoShanServe"`——**不推荐**（过滤弱）。

## 出站策略（防双报）

| 源 `SyncType` | 迁入后 `SyncStatus` | 说明 |
|---------------|---------------------|------|
| 1 成功 | **`Success`** | 已报政府；Worker 不得再推 |
| 0 待同步 | `Pending` | 切流后由 UM Worker 接手（确认 Serve 出站已停） |
| 2 失败 | `Failed` 或 `Pending` | 默认 `Failed` 保留可 Reset；或统一 `Pending` 重试——实现前定 Q13 |

**硬约束**：迁移窗口内 XiaoShanServe `ExplortStatisticBgService` 必须停，或只迁 `SyncType=1` 且目标一律 `Success`。

## 项目主数据

流水迁移**依赖** UM 已有对应 `GovProject`（`AccessCode` = 源 `BuildLicenseNo`）。

可选前置：

1. 从 `Gov_Project` 导出 AccessCode / 名称清单，在 UM Web 或 seed 建项目（`Id` 新 Guid）。  
2. 维护对照表：`XiaoShanServe.ProId(string)` → `UM.GovProject.Id`。  
3. 无匹配 AccessCode 的流水 → **跳过并记失败清单**，禁止静默丢进错误项目。

凡东码：源表若仅有 `FdBuildLicenseNo` 已换出的 `BuildLicenseNo`，以城管码为准；UM 不落凡东码列。

## 图片迁移

```text
源路径 = FilesPhysicalPath + 规范化(snapImages 分段)
     → 读字节
     → UM IFileService.SaveAndCompressImageBytesAsync / 等价落盘+AttachmentFile
     → AttachmentIds → 关联 UrbanWeighingRecord
```

注意：

- 路径中的 `//` 与反斜杠需规范化；文件缺失 → 行可迁业务字段，附件记 warn，或整行失败（Q14）。  
- 同机可硬链/复制到 UM `Storage` 根，避免两套权威长期并存。  
- AttachType：与在线一致，默认全部 **`Lpr`**（D9）。

## 主键与 `ClientRecordId`（批迁已确认）

| 字段 | 批迁规则 |
|------|----------|
| UM `UrbanWeighingRecord.Id` | **每次插入重新生成** Guid；**不**使用、不编码源 `Gov_SyncData.Id` |
| `ClientRecordId` | **一律 `00000000-0000-0000-0000-000000000000`（`Guid.Empty`）** |
| 源 `Id` | 仅可出现在迁移日志 / 对账报告，**不**落实体列（`sourceData` 已丢弃） |

含义与后果：

- 批迁行**不**依赖 `ClientRecordId` 幂等；重跑防重须另做（例如按源库文件指纹 + 已迁行数对账，或迁移工具侧记录「已处理源 Id」清单，**不**进业务表）。
- **不得**走现有 `ReceiveAsync` 主路径原样插入：现行实现拒绝 `ClientRecordId == Guid.Empty`，且唯一索引会把「多行全 0」打成冲突。批迁应：**专用插入路径**（绕过 Empty 校验 + 允许 Migrated 行 `ClientRecordId` 全 0），或调整唯一索引为「仅非 Empty 唯一」（Filtered unique / 条件索引）。实现时在 OpenSpec design 二选一写死。
- 在线 Legacy（`IngestSource=Legacy`）按 [02](./02-字段映射与缺口.md) **方案 A**：每次 `Guid.NewGuid()`（与批迁 `Empty` 分离）。

## 实施方式（选型）

| 方案 | 做法 | 适用 |
|------|------|------|
| **M1. 一次性迁移工具** | `pipelines/graphs/...` ingest（Node sqlite）或 `scripts/*.ps1` + 调用 UM 内部 API | **推荐**：可 dry-run、可 committable 证据包 |
| M2. UM 临时 AppService | `MigrateFromXiaoShanServeAsync(path)`，Admin only，迁完删除/Obsolete | 行数不大、同进程读 SQLite |
| M3. 纯 SQL 插行 | 手写 INSERT | **不推荐**：绕过附件与校验 |

映射函数建议 type-owned / static：`UrbanWeighingRecord.FromXiaoShanGovSyncData(...)`（与在线 Legacy 共用 SiteType/重量解析），**禁止**新建 MappingService（`minimal-di`）。

与 INT-006 关系：

- **在线路径**：INT-006 / `LegacyGovSyncAppService`  
- **历史批迁**：可同 initiative 第二 change，或同 change 末尾 tasks；**不得**阻塞在线切换太久——可先切流再迁历史（已 Success 行优先）。

## 建议执行顺序

1. 停 Serve 出站（或只读库拷贝）。  
2. 对齐 / 导入 `GovProject`（AccessCode）。  
3. dry-run：行数、缺图、缺项目、SyncType 分布报告。  
4. 正式迁：优先 `SyncType=1` → `Success`；再迁 0/2。  
5. 对账：源行数 vs 目标 `IngestSource=Migrated` 行数；抽样车牌/重量/时间。  
6. 保留源库只读备份；UM 成为唯一在线权威。

## 明确不做

| 做法 | 原因 |
|------|------|
| 迁入 UM `GovSyncData` 表 | D19 停双写；权威是 `UrbanWeighingRecord` |
| 保留或迁入源 `sourceData` | **丢弃** |
| 用源 `Id` 生成目标主键或 `ClientRecordId` | 主键重生成；`ClientRecordId` 全 0 |
| 迁入后把批迁行当 Modern Receive 幂等键 | 全 0 无客户端幂等语义 |
| 迁移后 Serve 继续出站同一批 | 双报 |
| 无 AccessCode 对照仍强行写入 | 脏 `ProId` |
| 把迁移逻辑塞进 `LegacyApiController` | 批处理 ≠ HTTP 入站 |
| Agent 宣布生产迁移 L3 通过 | pipelines / 人闸 |

## 开放问题

| # | 问题 | 默认建议 |
|---|------|----------|
| Q11 | `IngestSource` 是否增加 `Migrated=2`？ | **是** |
| Q12 | 无图行：跳过附件仍建记录，还是整行失败？ | 建记录 + 失败清单 warn |
| Q13 | 源失败行迁入 `Failed` 还是 `Pending`？ | `Failed` |
| Q14 | `CreationTime` 是否强制等于源 `AddTime`？ | 尽量保留 |
| Q15 | 迁移与 INT-006 同 change 还是拆 change？ | **拆**；批迁已挂起为 [INT-007](../intake/2026-09/INT-007-xiaoshanserve-govsyncdata-migrate.md) |
| Q16 | 现场库路径 / 文件根如何配置？ | secrets / 运维参数，不进仓库 |

## 落地规模（参考）

| 切片 | 档位 |
|------|------|
| 映射 + dry-run 报告 + 幂等批迁工具 | **M–L**（消化 INT-007 时） |
| 含全量图片复制与生产对账 | **L**（数据量敏感） |

**本期挂起**：不估算进在线 Legacy change。开 OpenSpec 后 effort 只写 `.openspec.yaml`。
