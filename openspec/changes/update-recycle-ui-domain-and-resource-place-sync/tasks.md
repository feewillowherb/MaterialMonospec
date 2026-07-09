## 1. Recycle 领域 Service

- [ ] 1.1 定义 `UpdateRecycleModeInput` record 与 `IRecycleWeighingService` 接口
- [ ] 1.2 实现 `RecycleWeighingService.UpdateRecycleModeAsync`（Waybill/WeighingRecord 分支，不含 SolidWaste ExtraProperties）
- [ ] 1.3 在 Common 模块 DI 注册 `IRecycleWeighingService`

## 2. Recycle 独立表单与 ViewModel

- [ ] 2.1 复制 `SolidWasteModeFormView.axaml` → `RecycleModeFormView.axaml`，删除联单/镇街/类型三行
- [ ] 2.2 新建 `RecycleWeighingDetailViewModel`（Load/Save/Complete 跳过 SolidWaste 配置与校验）
- [ ] 2.3 `RecycleWeighingDetailViewModel` 注入并调用 `IRecycleWeighingService`，移除 `UpdateSolidWasteModeAsync` 调用
- [ ] 2.4 `AttendedWeighingDetailView.axaml` 注册 `RecycleWeighingDetailViewModel` → `RecycleModeFormView` DataTemplate
- [ ] 2.5 `AttendedWeighingViewModel` Recycle 分支改为创建 `RecycleWeighingDetailViewModel`

## 3. LPR 无 CameraConfigs 双附件（Common）

- [ ] 3.1 `HikvisionLprService` / `VzvisionLprService`：无 CameraConfigs 时允许非 UrbanMode 落盘
- [ ] 3.2 `WeighingRecordService.SaveLprAttachmentAsync`：无 CameraConfigs 时额外插入 `UnmatchedEntryPhoto`（同路径）
- [ ] 3.3 `CreateWeighingRecordAsync`：有 LPR 且（UrbanMode 或无 CameraConfigs）时调用 `SaveLprAttachmentAsync`
- [ ] 3.4 验证有 CameraConfigs 时 LPR 不自动创建 `UnmatchedEntryPhoto`

## 4. §2.3 DTO 与 API

- [ ] 4.1 新增 `RecycleMaterialTransportRecord` DTO 与 `FromWaybill` 映射（kg、inTime、inPhoto）
- [ ] 4.2 `IRecycleDataApi` 增加 `SubmitMaterialTransportRecordAsync`（§2.3 addBatch）
- [ ] 4.3 更新 `RecycleTransportRecord.FromWeighingRecord`：`dataNo`=OrderNo、`carrierCompanyName`、移除 ProductName 配置依赖

## 5. RecycleDataSyncService 重构

- [ ] 5.1 扩展 `RecycleSyncStateStore` 支持 Waybill 级同步状态（ExtraProperties）
- [ ] 5.2 扫描逻辑改为：`WeighingMode=Recycle` + `OrderType=Completed` 的 Waybill，每单一次
- [ ] 5.3 按 `DeliveryType` 分流：Sending→§2.2，Receiving→§2.3
- [ ] 5.4 照片取图改为进场侧（EntryPhoto → UnmatchedEntryPhoto → Lpr），聚合 Waybill 关联附件
- [ ] 5.5 映射 `carrierCompanyName`（ProviderId → ProviderName）；`productName`/`materialName` 来自 Material.Name
- [ ] 5.6 OrderNo 为空时跳过上报（不用 R-{id} 回退）；净重非正跳过

## 6. 回归与验收

- [ ] 6.1 Recycle UI：表单无联单/镇街/类型，完成时不强制联单
- [ ] 6.2 Recycle 发料：已完成 Sending Waybill → §2.2 payload 字段与 `_temp/resource-place-api-test` 一致
- [ ] 6.3 Recycle 收料：已完成 Receiving Waybill → §2.3 payload（kg、inTime、inPhoto）
- [ ] 6.4 无 CameraConfigs + LPR：PhotoGrid 进场格可见，同步照片 Base64 非空
- [ ] 6.5 SolidWaste/Standard 客户端构建与无相机 LPR 负向回归
- [ ] 6.6 同一 Waybill 进/出场两条记录仅触发一次市平台 POST
