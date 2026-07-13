## Why

`MaterialClient.Recycle`（5020）在 `fix-recycle-client-auth-and-resource-place-sync` 中已具备授权/登录与 §2.2 基础上报管线，但仍共用 `SolidWasteWeighingDetailViewModel` 与 `UpdateSolidWasteModeAsync`，同步层未按收/发分流、未完成运单门槛、字段映射与设计定稿不一致（`dataNo`、进场照片、`carrierCompanyName`），且 §2.3 收料端点未实现。资源化利用厂现场需独立 Recycle 表单/领域 API，并在运单完成后按 `DeliveryType` 分别上报 §2.2/§2.3。

设计依据：material-client-vault `docs/2026-07-09-recycle-ui-22-23-gap-analysis/`（综合设计定稿 9 条）。

## What Changes

- 新建 `RecycleModeFormView` + `RecycleWeighingDetailViewModel`，Recycle 不再复用 SolidWaste 表单/VM（无联单/镇街/类型）
- 新建 Recycle 独立领域 Service/API（如 `IRecycleWeighingService`、`UpdateRecycleModeAsync`），**禁止** Recycle 调用 `UpdateSolidWasteModeAsync`
- 无 `CameraConfigs` 时 LPR 落盘并双附件（`Lpr` + `UnmatchedEntryPhoto` 同路径），供 PhotoGrid 与市平台取图
- 重构 `RecycleDataSyncService`：仅 **运单已完成**（`OrderTypeEnum.Completed`）上报；**每个 Waybill 仅上报一次**；按 `DeliveryType` 分流 §2.2（Sending）/ §2.3（Receiving）
- 字段映射对齐设计定稿：`dataNo` = `Waybill.OrderNo`；`productName`/`materialName` = `Material.Name`；`carrierCompanyName` = `Provider.ProviderName`；§2.2/§2.3 照片均取进场侧附件；§2.2 重量吨、§2.3 重量 kg
- 新增 §2.3 Refit 客户端、`RecycleMaterialTransportRecord` DTO 及映射逻辑
- 同步状态承载于 Waybill 级或等价去重机制，避免进/出场两条 `WeighingRecord` 重复上报同一 `dataNo`

## Capabilities

### New Capabilities

- `recycle-weighing-form`: Recycle 独立表单 View/ViewModel 与 AttendedWeighing 集成
- `recycle-weighing-service`: Recycle 领域保存/完成 API，与 SolidWaste 解耦
- `recycle-material-transport-record-dto`: §2.3 收料请求 DTO 与 Refit 端点定义

### Modified Capabilities

- `detail-viewmodel-hierarchy`: Recycle 模式创建 `RecycleWeighingDetailViewModel`，不再创建 `SolidWasteWeighingDetailViewModel`
- `recycle-data-sync`: 运单完成门槛、Waybill 级去重、收/发分流、§2.3 上报、进场图取图、`carrierCompanyName` 映射
- `recycle-transport-record-dto`: `dataNo`/重量/时间/照片/`productName` 映射规则更新（移除配置项 `ProductName` 依赖）
- `license-plate-recognition`: 无 CameraConfigs 时 LPR 落盘 + `UnmatchedEntryPhoto` 双附件（Common 层）

## Impact

- **MaterialClient.AttendedWeighing**：新建 `RecycleModeFormView`、`RecycleWeighingDetailViewModel`；`AttendedWeighingDetailView` DataTemplate；`AttendedWeighingViewModel` Recycle 分支
- **MaterialClient.Common**：新建 `IRecycleWeighingService` / 实现；`WeighingRecordService`、LPR 服务（无相机双附件）
- **MaterialClient.Recycle**：`RecycleDataSyncService`、`RecycleTransportRecord`、`IRecycleDataApi` 扩展 §2.3；新增 `RecycleMaterialTransportRecord`
- **无影响**：UrbanManagement、MaterialPlatform 同步、5000/5010/5001 客户端业务逻辑（LPR Common 改动需 Standard/SolidWaste 无相机场景回归）
