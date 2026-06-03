## Why

UrbanManagement 称重记录列表目前仅支持查询与展示（含 `IsAnomaly`、同步状态），管理员无法在 Web 端修正车牌/重量并触发与 MaterialClient.Urban 一致的「审批」流程。客户端已在本地完成审批（编辑 → 校验 → 重算异常 → 复位待同步 → 后台重传）；服务端收到记录后若数据有误，只能等客户端重传或手工改库。需要在 UrbanManagement 提供 **与客户端行为对齐** 的 Web 审批能力。

## What Changes

- 在称重记录 LayUI 列表增加 **「审批」** 操作列，打开审批弹层（车牌、重量可编辑）。
- 新增 **`IUrbanWeighingRecordAppService.ApproveAsync`**（或等价命名）：更新 `PlateNumber`、`TotalWeight`；按与客户端相同规则 **重算 `IsAnomaly`**；将 **`SyncType` 复位为待同步（0）**；**不在 UI 线程立即调用政府同步 HTTP**（由既有 `GovSyncBackgroundWorker` 扫描）。
- 新增服务端 **异常检测**（`IUrbanAnomalyDetector` + `UrbanAnomalyDetection` 配置节），规则与 `MaterialClient.Common` 的 `UrbanAnomalyDetector` 一致。
- 新增 **中国车牌格式校验**（与客户端 `PlateNumberValidator` 语义一致），审批保存前校验。
- **不包含** 图片/附件的查看、上传、替换或删除；审批仅修改车牌与重量。
- 附件只读预览（LPR/现场图）**本期不做**，在设计与代码中预留 TODO 供后续迭代。
- 新增 ABP 约定 API：`POST /api/app/urban-weighing-record/approve`（具体路由以 ABP 生成为准）。

## Capabilities

### New Capabilities

- `urbanmanagement-weighing-record-approval`: UrbanManagement Web 端称重记录审批（列表操作、审批弹层、车牌/重量编辑、校验、异常重算、同步状态复位；不含图片功能）。

### Modified Capabilities

- `urban-weighing-api`: 增加服务端审批 API 与审批输入/输出 DTO；明确审批后 `SyncType` 与 `IsAnomaly` 的更新语义。
- `gov-sync-worker`: 明确审批复位 `SyncType` 后记录重新进入政府同步扫描队列（行为说明，无 Worker 逻辑变更除非缺口）。

## Impact

| 区域 | 说明 |
|------|------|
| `UrbanManagement.Core` | `UrbanWeighingRecordAppService`、审批 DTO、异常检测服务、车牌校验（无附件 API） |
| `UrbanManagement.App` | `Views/UrbanWeighingRecord/Index.cshtml`（操作列 + LayUI 弹层 + AJAX） |
| `appsettings.json` | `UrbanAnomalyDetection` 配置节（与客户端默认阈值对齐） |
| `MaterialClient.Urban` | **无变更**（客户端审批逻辑已存在；服务端审批修正的是已入库的 `UrbanWeighingRecord`） |
| OpenSpec | 新 capability spec + `urban-weighing-api`、`gov-sync-worker` delta |
