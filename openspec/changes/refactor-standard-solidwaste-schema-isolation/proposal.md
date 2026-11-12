## Why

Standard 与 SolidWaste 的称重、运单主表在内核 `MaterialClientDbContext` 上，固废字段写在共享实体的 `ExtraProperties`。产品专属列一旦加进内核模型，标准端、Urban 和 Recycle 的内核迁移会一起变。已部署库更新后必须还能读原来的称重、运单和附件。

## What Changes

- 沿用 Urban / Recycle 已落地的同库多 Context：产品专属表进入 `MaterialClient.Common.Standard` 与 `MaterialClient.Common.SolidWaste`，各自迁移历史，不拆 SQLite 文件。
- 内核继续拥有 `WeighingRecords`、`Waybills` 及附件、材料关联。不按模式复制或删除这些行。
- 固废专属字段落到 SolidWaste 扩展表，用逻辑 `WaybillId` / `WeighingRecordId` 关联。已有 `ExtraProperties` 复制进扩展表，不删除内核行，也不删除这些键。
- Standard 建立独立 Context 和迁移历史。共享称重列仍在内核；以后的 Standard 专属列只进该 Context。
- 标准宿主先迁移内核，再迁移 Standard，再迁移 SolidWaste。Urban / Recycle 宿主不迁移这两套产品 Context。
- 不提供会删数据的 Down。

## Capabilities

### New Capabilities

- `standard-solidwaste-schema-isolation`: 按 Urban / Recycle 的方式把 Standard 与 SolidWaste 的专属表和迁移从内核模型分开，并保留已有称重行。

### Modified Capabilities

- `product-dbcontext-isolation`: 标准宿主在内核迁移之后再迁移 Standard 与 SolidWaste；这两套迁移不得修改内核称重表和运单表。

## Impact

- **MaterialClient**：新增两个产品 Common 项目、标准宿主启动迁移、固废字段的扩展表写入。内核称重与运单的现有读写保持。
- **Urban / Recycle**：不引用、不迁移 Standard / SolidWaste Context。内核 `WeighingRecord` 与 `UrbanWeighingExtension.WeighingRecordId` 不变。
- 依据：`docs/2026-08-28-materialclient-product-ef-isolation/` 与已归档 `refactor-common-product-layers`。不拆数据库文件，不把共享称重主表切成两套物理表。
