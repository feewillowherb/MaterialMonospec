## 1. RecycleInfoExtensions

- [x] 1.1 新增 `MaterialClient.Common/Entities/RecycleInfoExtensions.cs`：键 `RecycleInfo.UnitPrice`、`RecycleInfo.SaleContractNo`；`WeighingRecord` 扩展 `Get/SetUnitPrice`、`Get/SetSaleContractNo`、`SetRecycleInfo`（风格对齐 `SolidWasteInfoExtensions`）
- [x] 1.2 单测：读写、null 置空、`SetRecycleInfo` 批量（可放 Common.Tests）

## 2. RecycleWeighingService WeighingRecord 分支

- [x] 2.1 `UpdateRecycleModeAsync` 的 WeighingRecord 分支：在更新主表字段后调用 `SetUnitPrice`/`SetSaleContractNo`（含 null 置空），再 `UpdateAsync`
- [x] 2.2 确认 Waybill 分支仍走 `UpsertRecycleExtensionAsync`，行为不变
- [x] 2.3 扩展 `RecycleWeighingServiceUpsertTests`（或等价）：覆盖 `ItemType=WeighingRecord` 写入/置空 ExtraProperties，且不创建 `RecycleWaybillExtension`

## 3. 匹配建单拷贝

- [x] 3.1 `WeighingMatchingService` 注入 `IRepository<RecycleWaybillExtension, Guid>`（或抽取与 `RecycleWeighingService` 共享的 upsert helper）
- [x] 3.2 在 `CreateWaybillAsync` 中 `CopySolidWasteInfoToWaybill` 旁新增 `CopyRecycleInfoToWaybillExtensionAsync`：仅 Recycle 模式；join 优先、out fallback；upsert `UnitPrice`/`SaleContractNo`，不写 `ReceivingTime`
- [x] 3.3 单测：对照 `WeighingMatchingServiceSolidWasteTransferTests`，覆盖 join 有值、fallback out、两侧皆无、非 Recycle 不写扩展

## 4. UI 回填

- [x] 4.1 `RecycleWeighingDetailViewModel.LoadRecycleDataAsync` WeighingRecord 分支：经 `RecycleInfoExtensions` 回填 `UnitPrice`/`SaleContractNo`
- [x] 4.2 确认 Waybill 分支仍从 `RecycleWaybillExtension` 回填（不变）

## 5. 验证

- [x] 5.1 `dotnet build MaterialClient.sln -o .build-verify`（或子仓库约定输出目录）通过
- [x] 5.2 相关单测通过
- [x] 5.3 `openspec validate fix-recycle-weighingrecord-extra-properties --strict` 通过
