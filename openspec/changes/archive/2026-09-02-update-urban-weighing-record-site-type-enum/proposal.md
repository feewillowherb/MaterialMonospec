## Why

`UrbanWeighingRecord.SiteType` 仍为 `string?`，而通行实体与 LPR 配置已使用领域枚举 `UrbanSiteType`（工地/消纳）。调研 P2 [D15](../../docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md#22-2026-09-02第二批--消歧) 要求**仅改类型**：属性名 `SiteType` 不变，持久化为 enum/`int`，与通行路径对齐，避免地磅 outbound 继续依赖自由文本。

## What Changes

- `UrbanWeighingRecord.SiteType`：`string?` → non-nullable `UrbanSiteType`（默认 `Construction`）；EF 列由 TEXT → INTEGER。
- Receive / Submit DTO：同名 `SiteType` 改为 `UrbanSiteType`；API JSON 使用字符串 enum 名（与 `SyncStatus` 一致）。
- 存量 migration：可识别的历史 string（如 `"1"`/`"2"`、枚举名）映射为 enum；无法识别 → `Construction`。
- Outbound：`GovSyncWeightPayload.siteType` **仍为政府协议 string**（`"1"`/`"2"`）；由 `XiaoshanWeighbridgeConverter.SiteType(UrbanSiteType)` 投影，**不改** D5 出站协议形状。
- MaterialClient：`UrbanWeighingRecordSubmitDto.SiteType` 改为 `UrbanSiteType`；上云时从地磅 LPR 行快照赋值（缺失则默认 `Construction`）。
- Git：**Mode B** — `dev-urban-entity-semantic`（`UrbanManagement` + `MaterialClient`）。

**本 change 不包含**：`EnableSync`→`IsSyncEnabled`；`GovSyncData.SiteType` 强类型（仍 `string?`，属 P3）；AccessCode 改名（INT-005）；`VehicleType` / `PlateColor`（D16）；通行实体（已是 `UrbanSiteType`）。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `urban-weighing-api`: 称重实体与 Receive DTO `SiteType` 为 `UrbanSiteType`。
- `gov-sync-worker`: 地磅 outbound `siteType` 由 enum 转换，协议字段仍为 string。
- `xiaoshan-three-channel-gov-upload`: 地磅通道增加/对齐 `UrbanSiteType`→wire 转换。
- `entity-migration`: `UrbanWeighingRecord.SiteType` 列类型与实体形状。
- `materialclient-urban-desktop`: 称重上云 DTO `SiteType` 为 enum 并赋值。
- `proid-data-pipeline`: 上传 payload 中 `siteType` 语义对齐 enum。

## Impact

- **UrbanManagement**：`UrbanWeighingRecord`、Receive DTO、EF migration、`GovSyncWeightPayload.FromRecord`、Xiaoshan weighbridge converter、Blazor 展示（若有）、Tests。
- **MaterialClient**：`UrbanWeighingRecordSubmitDto`、`UrbanServerUploadService` 赋值路径、Tests。
- **GovSyncData / FdSoft.BasePlatform**：无变更。
- **Outbound 政府 API**：wire 值仍 `"1"`/`"2"`，仅来源改为 enum。
