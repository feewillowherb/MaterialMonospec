## Why

UrbanManagement 与 MaterialClient 对 `ProId` 的类型纪律不一致：称重/通行实体为 `Guid?`，在线态表为 `string`，只读 `GovSyncData` 仍为 `string?`，Receive/Submit API 允许缺失或 `Guid.Empty`。调研 P2 决策 [D12](../../docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md#22-2026-09-02第二批--消歧) 要求 **创建时必填 non-nullable `Guid`**，写入边界拒绝 `Guid.Empty`；非法历史在线态行 migration **忽略**（D14）。

## What Changes

- `UrbanWeighingRecord` / `UrbanPassageRecord`：`ProId` 收紧为 non-nullable `Guid`；Receive / 工厂方法必填。
- `ClientOnlineStatus` / `ClientDeviceOnlineStatus`：`ProId` 列由 `string` → `Guid`；Hub 持久化前校验格式。
- `GovSyncData`（只读）：`ProId` 列 `string?` → `Guid`（migration 可解析则转换，否则 `Guid.Empty`；无新写入）。
- UrbanManagement Receive DTO / AppService：**拒绝**缺失 `ProId` 或 `Guid.Empty`（**BREAKING** 对非法 payload）。
- MaterialClient：`UrbanWeighingRecordSubmitDto` / `UrbanPassageSubmitDto` 的 `ProId` 为 required `Guid`；上云路径从 `LicenseInfo.ProjectId` 必填赋值。
- SignalR `DeviceStatusMessage` **wire JSON 仍为 string**（`proId` claim 兼容）；服务端映射到实体时使用 `Guid` 并校验。
- EF migration：上述列类型/non-nullable；**不修复** D14 定义的非法在线态历史行（删除或跳过迁移不可解析行，见 design.md）。
- Git：**Mode B** — `dev-urban-entity-semantic`（`UrbanManagement` + `MaterialClient`）。

**本 change 不包含**：`SiteType` enum（`update-urban-weighing-record-site-type-enum`）、`EnableSync`→`IsSyncEnabled`（`rename-gov-project-enable-sync-to-is-sync-enabled`）、AccessCode 重命名（[INT-005](../../docs/intake/2026-09/INT-005-urban-entity-accesscode-rename.md)）、Legacy 完整实现（[INT-006](../../docs/intake/2026-09/INT-006-legacy-gov-sync-reimplementation.md)）。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `urban-weighing-api`: 实体与 Receive DTO `ProId` non-nullable `Guid`；边界校验。
- `urban-passage-record`: 通行实体 `ProId` non-nullable；创建路径必填。
- `proid-data-pipeline`: 上云 DTO `ProId` required；缺失 license 时 fail-fast 或不上传（见 design）。
- `device-online-status-persistence`: 在线态实体 `ProId` 为 `Guid`；非法历史行 migration 忽略。
- `signalr-device-status-upload`: Hub 持久化前 `ProId` Guid 校验；wire 仍为 string。
- `entity-migration`: 上述实体 `ProId` 形状统一为 non-nullable `Guid`。
- `materialclient-urban-desktop`: Submit DTO 与上传路径 `ProId` required。

## Impact

- **UrbanManagement**：Entities、EF migrations、Receive AppServices、Passage 工厂、DeviceStatus Hub/Service、在线态查询、DTOs、Tests。
- **MaterialClient**：Urban submit DTOs、上传 Service、SignalR 消息构造（仍为 string wire）、Tests。
- **GovSyncData**：只读 schema 对齐；无业务写入变更。
- **FdSoft.BasePlatform**：无变更。
