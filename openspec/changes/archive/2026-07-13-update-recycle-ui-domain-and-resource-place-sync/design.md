## Context

`MaterialClient.Recycle`（5020）已完成授权/登录与 §2.2 HMAC 上报基础（`fix-recycle-client-auth-and-resource-place-sync`），但 UI 仍挂载 `SolidWasteWeighingDetailViewModel`，保存/完成走 `UpdateSolidWasteModeAsync`；同步按 `WeighingRecord` 扫描、不校验运单完成态、不区分收/发，照片取 `ExitPhoto`/`Lpr` 出场类，且 §2.3 未实现。

综合设计定稿（vault `docs/2026-07-09-recycle-ui-22-23-gap-analysis/`）已确认：`dataNo`= `Waybill.OrderNo`、API 照片取进场侧、UI 重量按吨、独立 Recycle 领域 API、仅已完成运单上报。

## Goals / Non-Goals

**Goals:**

- Recycle 独立表单 + ViewModel，与 SolidWaste 字段/校验解耦
- `IRecycleWeighingService` / `UpdateRecycleModeAsync` 专用领域 API
- 无 CameraConfigs 时 LPR 双附件（Common 层）
- `RecycleDataSyncService` 重构：Waybill 级、已完成门槛、§2.2/§2.3 分流、字段映射对齐
- §2.3 `RecycleMaterialTransportRecord` + Refit 端点

**Non-Goals:**

- §2.1、§2.4–§2.10 其他市平台接口
- UrbanManagement / MaterialPlatform 同步链路
- Recycle 联单/镇街/类型 UI 或 SolidWaste 导出逻辑
- LPR 双附件删除/替换专项逻辑
- BasePlatform 5020 注册（已在其他 change 完成）
- OpenSpec 范围外的技术债务清理

## Decisions

### D1: Recycle 独立 ViewModel + FormView

**选择**：新建 `RecycleModeFormView.axaml`（自 `SolidWasteModeFormView` 复制并删除联单/镇街/类型三行）与 `RecycleWeighingDetailViewModel`；`AttendedWeighingDetailView` 增加 DataTemplate。

**理由**：SolidWaste 完成校验强制联单/镇街，与 Recycle 市平台需求不符。

**替代**：Recycle 继续传 null 给 SolidWaste API — 已否决（设计定稿 #6 禁止 SolidWaste 领域 API）。

### D2: Recycle 领域 Service 独立于 WeighingMatchingService SolidWaste 路径

**选择**：新增 `IRecycleWeighingService` + `UpdateRecycleModeAsync(UpdateRecycleModeInput input)`，入参含 `ItemType`、`Id`、`PlateNumber`、`ProviderId`、`MaterialId`、`MaterialUnitId`、`DeliveryType`、`Remark`；**不含** SolidWaste 专用字段。

**理由**：避免 Recycle 写入 `SolidWasteInfo` ExtraProperties；事务边界仍用 `[UnitOfWork]`。

**替代**：扩展 `UpdateSolidWasteModeAsync` 可选参数 — 已否决。

### D3: 同步粒度 — Waybill 级、每单一次

**选择**：`RecycleDataSyncService` 扫描 **`WeighingMode=Recycle` 且 `OrderType=Completed` 的 Waybill**，每个 Waybill **仅上报一次**；同步状态写入 **Waybill.ExtraProperties**（扩展 `RecycleSyncStateStore` 或等价 helper）。

**理由**：设计定稿 #9；避免进/出场两条 `WeighingRecord` 用同一 `dataNo` 重复 POST。

**替代**：继续扫 WeighingRecord + 内存去重 — 未采用（状态难持久化）。

#### 上报分流

| Waybill 条件 | 端点 | DTO |
|--------------|------|-----|
| `DeliveryType.Sending` | §2.2 `productTransportRecord/v1/addBatch` | `RecycleTransportRecord` |
| `DeliveryType.Receiving` | §2.3 `materialTransportRecord/v1/addBatch` | `RecycleMaterialTransportRecord` |

### D4: 字段映射

| 字段 | 来源 |
|------|------|
| `dataNo` | `Waybill.OrderNo`（必填；缺失则跳过并 Warn，**不用** `R-{id}` 回退） |
| `productName` / `materialName` | `Material.Name`（WaybillMaterial → MaterialId → Materials 首项） |
| `carrierCompanyName` | `ProviderId` → `Provider.ProviderName`（可空则省略） |
| `carNo` | `Waybill.PlateNumber` |
| §2.2 `outTime` | `Waybill.OutTime` |
| §2.3 `inTime` | `Waybill.JoinTime` |
| 净/皮/毛 | `OrderGoodsWeight` / `OrderTruckWeight` / `OrderTotalWeight`（内部 kg） |
| §2.2 重量 API | kg ÷ 1000 → **吨** |
| §2.3 重量 API | **kg** 原值（与 UI 吨显示无关，Mapper 负责） |
| 照片 | 运单关联附件，进场侧：`EntryPhoto` → `UnmatchedEntryPhoto` → `Lpr`；Base64 无标识头，逗号分隔 |

### D5: 无 CameraConfigs 时 LPR 双附件

**选择**：`CameraConfigs.Count == 0` 时，LPR 落盘（不限 UrbanMode）+ `SaveLprAttachmentAsync` 写 `Lpr` 与 `UnmatchedEntryPhoto`（同 `LocalPath`）；有 CameraConfigs 时行为不变。

**理由**：vault `04-仅有Lpr设备方案.md`；PhotoGrid 不展示 `Lpr` 类型。

**实现位置**：`MaterialClient.Common`（`WeighingRecordService`、Hik/Vz LPR 服务）。

### D6: §2.3 API 扩展

**选择**：在 `IRecycleDataApi` 增加 `SubmitMaterialTransportRecordAsync(List<RecycleMaterialTransportRecord>, CancellationToken)`；DTO 字段对齐接口文档 §2.3。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| LPR Common 改动影响 Standard/SolidWaste | 负向测试：有 CameraConfigs 时不创建 UnmatchedEntryPhoto；无相机场景回归 |
| Waybill 级同步状态迁移 | 新 Waybill ExtraProperties 键；旧 WeighingRecord 同步状态可保留但不驱动新逻辑 |
| 运单无进场图时 API 必填照片失败 | 记录 Warn；仍尝试上报或跳过（与 §2.2 现网一致：空串可能业务失败，计入 FailCount） |
| Recycle VM 与 SolidWaste 代码重复 | 可抽取共享基类；本 change 允许先复制后 refactor（Non-Goal 不强制大 refactor） |

## Migration Plan

1. 部署 Recycle 客户端新版本；`RecycleSync` 配置不变（`PointNumber`、HMAC 密钥）
2. 已完成但未上报的历史 Waybill：首轮扫描补报（若 ExtraProperties 无已同步标记）
3. 回滚：恢复旧 exe；Waybill ExtraProperties 同步标记不影响称重业务

## Open Questions

- 无（综合设计定稿已覆盖；同步粒度本 design 已定为 Waybill 级一次）
