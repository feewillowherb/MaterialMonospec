## Why

MaterialClient 本地 `WeighingRecord.TotalWeight` 以**吨**存储并展示（Urban 称重区单位为「吨」），而 UrbanManagement 的 `UrbanWeighingRecord.TotalWeight`、Web 审批表单与政府同步 `GovSyncBackgroundWorker`（如 `carType` 以 4500 **kg** 为界）均以**千克**为语义。当前 `UrbanServerUploadService` 将 `record.TotalWeight` 原样提交，导致服务端存数偏小约 1000 倍，政府上报与列表展示错误。

## What Changes

- **MaterialClient.Urban**：在 `ReceiveWeighingRecordAsync` 提交前，将 `TotalWeight` 从吨转换为 kg（复用 `MaterialMath.ConvertTonToKg`），仅影响上云 DTO，不修改本地库单位。
- **规范**：在 `urban-weighing-api` / `urban-weighing-record-reception` 中明确 `totalWeight` 线上载荷单位为 **kg**。
- **UrbanManagement（配置）**：将 `UrbanAnomalyDetection` 默认上下限从「吨」量纲调整为「千克」（如 30000 / 2000），与 `ApproveAsync` 服务端复检及存库单位一致（接收路径仍优先使用客户端 `IsAnomaly`）。

## Capabilities

### New Capabilities

- `urban-weight-upload-unit`: MaterialClient.Urban 上云称重记录时 MUST 将重量由吨换算为千克再写入 `UrbanWeighingRecordSubmitDto.totalWeight`。

### Modified Capabilities

- `urban-weighing-api`: 补充 `Receive` / 存储字段 `TotalWeight` 的单位为千克及换算场景。
- `urban-weighing-record-reception`: 同步 DTO 字段单位说明。
- `materialclient-urban-desktop`: 上云管线重量换算要求。
- `urban-anomaly-detection`: 服务端阈值配置量纲改为千克（与存库一致）。

## Impact

| 范围 | 说明 |
|------|------|
| **MaterialClient.Urban** | `UrbanServerUploadService`（及 DTO 构建处）；可选单元测试 |
| **UrbanManagement** | `appsettings.json` 中 `UrbanAnomalyDetection` 默认值；无 API 契约破坏性变更 |
| **已有脏数据** | 已按「吨数值当 kg」入库的记录需人工或脚本修正；本 change 不批量迁移 |
| **非目标** | 不改本地 `WeighingRecord` 存储单位；不改称重 UI 显示单位；不改政府 API 字段名 |
