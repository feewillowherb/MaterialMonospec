## Context

当前 Urban 称重上云链路：

```
客户端称重 → 本地 Pending → PollingBackgroundService → ReceiveAsync（首次插入）
客户端审批 → UpdateWeighingRecordAsync（本地改字段 + SyncStatus=Pending）
           → PollingBackgroundService → ReceiveAsync（ClientRecordId 已存在 → 仅返回 ID）
```

服务端 `UrbanWeighingRecordAppService.ReceiveAsync` 在 `ClientRecordId` 命中已有记录时，自归档 change `urban-upload-weight-ton-to-kg` 的 **D4** 起 intentionally **不覆盖**业务字段，以避免重复上云覆盖 Web 人工审批。但该决策未覆盖「客户端现场审批后重传」场景，造成客户端本地 `Synced` 与服务端旧数据并存。

Web 端已有独立 `ApproveAsync`（按服务端 Guid 审批），MaterialClient 不存储服务端 Guid，无法直接调用。客户端重传只能走 `ReceiveAsync` + `ClientRecordId` 定位。

## Goals / Non-Goals

**Goals:**

- 客户端审批后 Pending 重传时，UrbanManagement 服务端记录与客户端 DTO 保持一致（车牌、重量、异常标记、异常原因、编辑历史）。
- 当客户端重传 `IsAnomaly == false` 时，服务端复位政府同步状态（`SyncType = 0`、`RetryCount = 0`），与 Web `ApproveAsync` 语义对齐。
- 保持 `ClientRecordId` 唯一约束与幂等接收 API 不变；不新增 Refit 路由。
- 补充可自动化验证的测试场景。

**Non-Goals:**

- 不改变 Web 端 `ApproveAsync` 实现与 UI。
- 不引入服务端异常阈值重算（仍遵循 `urban-anomaly-client-only`：接收路径以客户端 `IsAnomaly` 为准）。
- 不批量修正历史已错误入库的数据（运维脚本另议）。
- 不在客户端 UI 线程同步 HTTP 上传（仍由 `PollingBackgroundService` 负责）。

## Decisions

### D1: 在 ReceiveAsync 去重路径执行 upsert（而非新增 API）

**选择**：扩展 `ReceiveAsync` 现有分支：当 `ClientRecordId` 已存在时，按入参 DTO **更新可变字段**，**不**处理 `AttachmentIds`。

**理由**：

- 客户端仅知 `ClientRecordId`（本地 `WeighingRecord.Id`），无服务端 Guid。
- 重传已走 `ReceiveWeighingRecordAsync`，改行为即可，零客户端路由变更。
- 与 OpenSpec「接收并去重」能力自然延伸，而非并行维护 `Receive` + `Update` 两套协议。

**备选**：客户端新增 `ApproveByClientRecordIdAsync` — 需新 DTO/路由/Refit，与 Web `ApproveAsync` 职责重叠，拒绝。

### D2: 去重 upsert 更新的字段集合

**选择**：对已有 `UrbanWeighingRecord` 更新以下字段（来自 input DTO）：

| 字段 | 说明 |
|------|------|
| `PlateNumber` | 审批修正车牌 |
| `TotalWeight` | kg，客户端已换算 |
| `IsAnomaly` | 以客户端上报为准，不重算 |
| `AnomalyReason` | 随客户端 |
| `ExtraProperties["EditHistory"]` | 若 DTO 提供则覆盖/合并（见 D3） |
| `ClientSyncType` / `ClientSyncTime` / `ClientRetryCount` / `ClientLastErrorTime` | 客户端同步元数据 |
| `SyncType` | 当 `input.IsAnomaly == false` 时设为 `0`（待政府同步） |
| `RetryCount` | 当 `input.IsAnomaly == false` 时设为 `0` |

**不更新**：`ClientRecordId`、`WeighingTime`、`AddTime`、项目字段（`ProId`/`ProName`/`BuildLicenseNo` 等）—— 首次入库后视为不可变上下文，避免重传覆盖许可证切换后的项目归属。

**理由**：审批仅修正车牌/重量及异常状态；称重时间与项目信息在首次接收时已确定。

### D3: EditHistory 合并策略

**选择**：若 input `ExtraProperties` 含 `"EditHistory"` 键，则 **整包替换** 服务端 `ExtraProperties["EditHistory"]`（客户端 `AppendEditEntryAsync` 已维护完整 JSON 数组）。

**理由**：客户端是编辑历史权威源；服务端 Web 审批亦写入同结构快照。重传时以客户端最新 JSON 为准，避免双端 append 冲突。

**备选**：按时间戳 merge — 复杂度高，当前无跨端并发编辑需求，拒绝。

### D4: 附件仅在首次接收时关联

**选择**：`LinkAttachmentsAsync` **仅**在新建记录路径调用；去重路径（`ClientRecordId` 已存在）**忽略**入参 `AttachmentIds`，不新增、不替换、不删除已有附件关联。

**理由**：

- 审批重传只修正车牌/重量等业务字段，不涉及图片变更。
- 避免重复上云或重传时覆盖/追加附件，保持首次入库时的附件快照稳定。

**备选**：去重路径继续补关联缺失附件 — 与用户「已存在则不更新附件」要求冲突，拒绝。

### D5: 客户端 SyncType 字段

**选择**：`UrbanServerUploadService` 构建 DTO 时，当关联 extension `IsAnomaly == false`，设置 `SyncType = 0`；异常记录保持 `SyncType = null` 或现状（不触发政府同步）。

**理由**：与 Web 审批后 `SyncType = 0` 一致；当前代码硬编码 `SyncType = 0` 需改为按异常状态条件设置，避免异常记录误复位政府同步队列。

### D6: 响应 DTO 不区分 create/update

**选择**：`UrbanWeighingRecordReceiveOutputDto` 仍只返回 `RecordId`；不新增 `WasUpdated` 标志。

**理由**：客户端仅依赖非空 `RecordId` 标记本地 `Synced`；行为变化对客户端透明。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 客户端重传覆盖 Web 端人工在服务端改过的车牌/重量 | 业务上客户端审批为现场权威；Web 审批后若客户端再次本地审批会重传覆盖——与双端审批共存的已知权衡，文档说明 |
| 异常记录重传仍带 `IsAnomaly=true` 时不复位 `SyncType` | 符合「异常不进政府同步」；客户端审批后本地重算应清除异常才进队列 |
| 撤销 D4「不覆盖重量」可能与旧运维假设冲突 | 本 change 明确 supersede 归档 D4 对审批重传场景的约束；纯网络重试（payload 未变）覆盖同值字段，无副作用 |
| EditHistory 整包替换丢失仅 Web 端写入的历史 | Web 审批后客户端未重传则不受影响；客户端重传时以客户端历史为准（客户端审批前已 AppendEditEntry） |
| 首次上云附件上传失败、重试时 ClientRecordId 尚未入库 | 仍走新建路径，可正常关联附件；仅去重路径跳过附件 |
| 客户端重传仍上传附件浪费带宽 | 可选优化：`UrbanServerUploadService` 在已知曾 `Synced` 的重传场景跳过附件上云（tasks 3.3） |

## Migration Plan

1. 部署 UrbanManagement.Core（服务端 upsert 逻辑 + 测试）。
2. 部署 MaterialClient.Urban（`SyncType` 条件赋值，若有变更）。
3. 无需数据库迁移（字段已存在）。
4. 回滚：还原 `ReceiveAsync` 去重分支为仅返回 ID；客户端无 schema 变更。

## Open Questions

（无 — 实现路径明确，可在 apply 阶段按 tasks 执行。）
