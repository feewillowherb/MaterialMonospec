## Why

UrbanManagement 卡口/成品 Receive 与列表页已在 `add-urbanmanagement-passage-xiaoshan-upload` 落地，但 MaterialClient 进出仍仅本地 SQLite，无法经 `UrbanManagement:BaseUrl` 上云。`urban-passage-um-reconcile` Graph 当前 Bridge 模式代 POST UM，不能验证真实客户端链路。需要统一客户端上云入口并完成 ClientUpload 联调 Graph。

## What Changes

- MaterialClient：新增 **统一** 进出上云服务 `IUrbanPassageUploadService`（单入口 `SubmitPassageRecordAsync`），按 `PassageSource` 内部分叉调用 UM 卡口/成品 Receive；共用同一 submit DTO `record`；附件先 multipart 再 ingest。
- `UrbanPassageRecord` 增加 `SyncStatus` / 重试字段；`PollingBackgroundService` 与创建后事件 Handler 扫描 pending 进出上云；称重上云路径不变。
- Refit `IUrbanManagementApi` 增加两条 Receive 方法（与 UM 已存在 API 对齐）。
- Pipeline `urban-passage-um-reconcile`：**WIP → active**：默认 **ClientUpload** 模式（配置客户端 BaseUrl → probe 灌数 → 等待客户端上云 → GET UM 列表对照）；移除 Bridge 作为默认/主路径；补充 `Start-UrbanForReconcile.ps1`。
- 依赖：`add-urbanmanagement-passage-xiaoshan-upload` UM 侧 tasks 2–6 已完成；本 change 完成剩余客户端 + Graph 联调。
- Git：**Mode A**（MaterialMonospec + MaterialClient 同名分支 `update-urban-passage-client-upload-reconcile`，squash 回 trunk）。

## Capabilities

### New Capabilities

- `urban-passage-client-upload`: 客户端统一进出上云（单 Service 入口、PassageSource 分叉、附件 + Receive、pending 扫描）。
- `urban-passage-um-reconcile`: ClientUpload 联调 Graph 协议（配置 BaseUrl、probe、cook、UM 列表 reconcile）。

### Modified Capabilities

- `urban-client-attachment-sync`: 进出记录关联附件的上传路径（按 attachment id，非 weighingRecordId）。
- `urban-polling-background-service`: 轮询除称重外 pending `UrbanPassageRecord` 上云。
- `materialclient-urban-desktop`: 联调场景下 `UrbanManagement:BaseUrl` 配置与诊断 Host 前置条件。

## Impact

- **MaterialClient**（`MaterialClient.Urban`、`MaterialClient.Common.Urban`）：实体 migration、Refit、Upload Service、Polling、Event Handler。
- **MaterialMonospec**（`pipelines/graphs/urban/urban-passage-um-reconcile/`）：脚本、pipeline.md、config（WIP → active）。
- **UrbanManagement**：无 API 变更（已就绪）。
- **OpenSpec 关系**：与 `add-urbanmanagement-passage-xiaoshan-upload` tasks 7.1–7.2 等价实现；归档时可合并 delta 或先归档本 change 再收尾父 change。
- 调研：`docs/2026-08-28-urbanmanagement-passage-xiaoshan-upload/`。
