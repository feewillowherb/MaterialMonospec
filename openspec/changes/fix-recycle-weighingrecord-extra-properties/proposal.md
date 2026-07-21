## Why

归档变更 `2026-07-21-materialclient-recycle-enhancement` 将 `UnitPrice`/`SaleContractNo` 仅持久化到按 `WaybillId` 关联的 `RecycleWaybillExtension`。用户在**生成 Waybill 之前**编辑未配对 `WeighingRecord` 时，表单虽透传两字段，但 `RecycleWeighingService` 的 WeighingRecord 分支忽略它们，`LoadRecycleDataAsync` 也不回填，导致编辑信息丢失。SolidWaste 已用 `WeighingRecord.ExtraProperties`（`SolidWasteInfoExtensions`）做运单前暂存，Recycle 应对齐该模式。

## What Changes

- **新增 `RecycleInfoExtensions`**：参考 `SolidWasteInfoExtensions`，在 `WeighingRecord.ExtraProperties` 上以类型安全扩展方法读写 `RecycleInfo.UnitPrice`、`RecycleInfo.SaleContractNo`（生成 Waybill 前的暂存）。
- **`UpdateRecycleModeAsync` WeighingRecord 分支**：保存时将 `UnitPrice`/`SaleContractNo` 写入上述 ExtraProperties（含 null 置空）；Waybill 分支继续 upsert `RecycleWaybillExtension`（行为不变）。
- **`LoadRecycleDataAsync` WeighingRecord 分支**：从 ExtraProperties 回填单价与合同号。
- **匹配建单时拷贝**：`CreateWaybillAsync`（自动/手动匹配共用）将 join/out 记录上的 Recycle ExtraProperties 拷贝并 upsert 到新建 Waybill 的 `RecycleWaybillExtension`（对齐 `CopySolidWasteInfoToWaybill`）。
- **不改动**：`ReceivingTime` 仍仅在收货动作写入扩展表；§2.2 上报仍只读 `RecycleWaybillExtension`；不向 Waybill 主表加列。

## Capabilities

### New Capabilities
- `recycle-info-extra-properties`：`RecycleInfoExtensions` 键约定与 WeighingRecord 读写；匹配建单时从 WeighingRecord ExtraProperties 拷贝到 `RecycleWaybillExtension`。

### Modified Capabilities
- `recycle-weighing-service`：`UpdateRecycleModeAsync` 在 `ItemType=WeighingRecord` 时持久化单价/合同号到 ExtraProperties；修正既有「写入 Waybill 列」表述为扩展表。
- `recycle-weighing-form`：打开 WeighingRecord 详情时从 ExtraProperties 回填 `UnitPrice`/`SaleContractNo`。

## Impact

| 范围 | 说明 |
|------|------|
| 子仓库 | MaterialClient only |
| 新增 | `MaterialClient.Common/Entities/RecycleInfoExtensions.cs` |
| 修改 | `RecycleWeighingService.cs`（WeighingRecord 分支）、`WeighingMatchingService.CreateWaybillAsync`（拷贝）、`RecycleWeighingDetailViewModel.LoadRecycleDataAsync` |
| 存储 | `WeighingRecord.ExtraProperties` JSON（ABP 既有列）；建单后仍用 `RecycleWaybillExtensions` 表 |
| 迁移 | 无需新 EF 迁移（ExtraProperties 列已存在） |
| 测试 | 扩展 `RecycleWeighingService` WeighingRecord 分支单测；新增匹配拷贝单测（对照 SolidWaste transfer tests） |
