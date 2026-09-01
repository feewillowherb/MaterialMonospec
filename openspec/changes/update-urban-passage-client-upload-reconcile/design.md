## Context

- 客户端 `add-urban-passage-record` 已本地写入 `UrbanPassageRecord`（卡口/成品 `PassageSource`）。
- UM `add-urbanmanagement-passage-xiaoshan-upload` 已提供：
  - `POST /api/app/urban-checkpoint-passage/receive`
  - `POST /api/app/urban-finished-product-passage/receive`
  - 列表 GET + Blazor 页
- 称重上云现网：`PollingBackgroundService` → `IUrbanServerUploadService.SubmitRecordAsync(weighingRecordId)` → 附件 multipart → `ReceiveWeighingRecordAsync`。
- `urban-passage-um-reconcile` Graph 已建但 **Bridge 代 POST**；`graph.status: wip`。本 design 完成 **ClientUpload** 真实链路。

约束：`type-owned-methods`、`minimal-di`、`no-database-fk`、`viewmodel-no-repository`；禁止 tuple；Git Mode A。

## Goals / Non-Goals

**Goals:**

- 客户端 **单一上云入口** `IUrbanPassageUploadService.SubmitPassageRecordAsync(Guid passageRecordId)`；内部按 `PassageSource` 调 UM 卡口或成品 Receive（**两个 HTTP 路径**，共用同一 submit DTO `record`）。
- 附件：上云前 multipart 上传 capture 文件，Guid 填入 ingest DTO。
- Pending 扫描：Polling + `UrbanPassageRecordCreatedEventData` 立即尝试（失败保留 Pending 供轮询重试）。
- Pipeline：配置 `UrbanManagement:BaseUrl` → 启动 Urban → `urban-passage-probe` → 等待上云 → UM 列表 reconcile（5+5 车牌）。

**Non-Goals:**

- 合并 UM 卡口/成品为 **一个** Receive API（UM 保持两 AppService）。
- 客户端直连萧山 Gov（tasks 7.3 仍禁止）。
- Gov 出站验收（仍人工 + `govsync/*`）。
- 修改 UM 实体/API。

## Decisions

### 1. 统一客户端接口 vs 两个 Service

**选择**：`IUrbanPassageUploadService.SubmitPassageRecordAsync(Guid)` 单入口；`PassageSource` 分叉选 Refit 方法。

**备选**：扩展 `IUrbanServerUploadService.SubmitRecordAsync` 接受 mixed id → 拒绝（称重 long vs 进出 Guid 类型混淆）。

### 2. Submit DTO

**选择**：命名 `record` `UrbanPassageSubmitDto`，静态 `FromPassage(UrbanPassageRecord, LicenseInfo, submitMachineCode, attachmentIds)`；字段对齐 UM `UrbanPassageReceiveFields`（含 `clientRecordId` = 客户端 `UrbanPassageRecord.Id`）。

### 3. 同步状态

**选择**：在 `UrbanPassageRecord` 增加 `SyncStatus`、`RetryCount`、`LastErrorTime`、`SubmitMachineCode`；类型归属方法 `MarkSynced()` / `MarkUploadFailed()` / `AssignSubmitMachineCode()`。

**备选**：独立 Extension 表 → 拒绝（进出无 weighing 父记录，字段可直接挂实体）。

### 4. 附件

**选择**：`IUrbanAttachmentSyncService.UploadPassageAttachmentsAsync(largeId, smallId, buildLicenseNo)`；按 `AttachmentFile` id 读本地路径 multipart；缺失文件 warn 跳过。

### 5. 触发

**选择**：

1. `UrbanPassageRecordCreatedEventHandler` 立即 `SubmitPassageRecordAsync`（同称重 upload-request 模式）。
2. `PollingBackgroundService` 追加 `IUrbanPassageRecordService.GetPendingForUploadAsync` 批次。

联调时 env 可设 `Urban__UploadPollingPeriodMs=5000` 缩短等待。

### 6. Pipeline ClientUpload

**选择**：

- `Start-UrbanForReconcile.ps1`：build + license seed + 写 `UrbanManagement__BaseUrl` + `MinimalWebHost__EnableOnStartup=true` + 可选缩短 poll。
- `Invoke-UrbanPassageUmReconcile.ps1` 默认 `-Mode ClientUpload`：跑 probe → 轮询 UM list 至超时或 5+5 对齐。
- **删除 Bridge 默认**；Bridge 可保留为 `_retired` 文档或 `-Mode Bridge` 隐藏调试（非主路径）。

### 7. Graph 状态

Apply 完成并 cook L0–L2 通过后：`graph.status: active`；此前保持 `wip`。

## Risks / Trade-offs

- [Bridge 与 ClientUpload 漂移] → 归档 Bridge 或仅 debug；spec 以 ClientUpload 为准。
- [Poll 间隔 80s 联调慢] → reconcile 脚本设 env 5s + 创建后立即 event upload。
- [父 change 7.x 重复] → 本 change 实现后标记 `add-urbanmanagement-passage-xiaoshan-upload` tasks 7.1–7.2 由 apply 同步勾选。

## Migration Plan

1. MaterialClient migration 增加 sync 列（UrbanDbContext）。
2. 部署客户端；`UrbanManagement:BaseUrl` 指向 UM。
3. Cook `urban-passage-um-reconcile` ClientUpload；L3 人工 Blazor。
4. Graph `wip` → `active`。

## Open Questions

无。
