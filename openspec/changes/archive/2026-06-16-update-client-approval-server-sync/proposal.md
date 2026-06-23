## Why

MaterialClient.Urban 客户端审批后会更新本地车牌/重量并将 `SyncStatus` 复位为 `Pending`，后台轮询再通过 `ReceiveAsync` 重传。但服务端 `ReceiveAsync` 对已有 `ClientRecordId` 仅做幂等返回（最多补附件关联），**不更新** `PlateNumber`、`TotalWeight`、`IsAnomaly` 等业务字段，导致 UrbanManagement 上已入库的数据与客户端审批结果不一致。现场操作员在客户端完成审批后，Web 端仍显示旧数据且异常记录无法进入政府同步。

## What Changes

- 扩展 UrbanManagement `ReceiveAsync` 的 **ClientRecordId 去重路径**：当记录已存在时，**同步更新**客户端重传的可变字段（车牌、重量、异常标记、异常原因、编辑历史、政府同步复位字段等），**不**关联或更新附件（附件仅在首次接收时写入）。
- 明确 **客户端审批 → Pending 重传 → 服务端 upsert** 的端到端语义，与 Web 端 `ApproveAsync` 审批后复位 `SyncType` 的行为对齐。
- 补充 MaterialClient.Urban 上传 DTO 中 `SyncType = 0` 的语义（审批后待政府同步），确保重传时服务端正确复位同步状态。
- 增加服务端单元测试与客户端集成场景测试，覆盖「首次上传 → 客户端审批 → 重传后服务端数据已更新」。
- **不新增**客户端 HTTP API 路由；继续复用 `POST /api/app/urban-weighing-record/receive`。
- **不修改** Web 端 `ApproveAsync` 的独立审批流程。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `urban-weighing-record-reception`: 去重路径由「仅返回 ID」扩展为「返回 ID 并 upsert 可变字段」。
- `urban-weighing-api`: 更新 `ClientRecordId` 幂等与 duplicate receive 场景的需求描述；明确重传时 `IsAnomaly`、`SyncType`、编辑历史的更新语义。
- `weighing-record-approval`: 补充审批后重传必须在服务端生效的验收场景。

## Impact

| 区域 | 说明 |
|------|------|
| `UrbanManagement.Core` | `UrbanWeighingRecordAppService.ReceiveAsync` 去重分支增加字段更新与政府同步复位逻辑 |
| `UrbanManagement.Core.Tests` | 新增/扩展 duplicate receive upsert 测试 |
| `MaterialClient.Urban` | `UrbanServerUploadService` 构建 DTO 时确保 `SyncType` 与审批后语义一致（若已有缺口则修正） |
| OpenSpec | 上述 capability delta specs |
| `MaterialClient.Common` | 无 API 变更；`UpdateWeighingRecordAsync` 行为保持不变 |
| Web 审批 / 政府同步 Worker | 行为受益（收到更正数据后可重新进入同步队列），无 Worker 逻辑变更除非缺口 |
