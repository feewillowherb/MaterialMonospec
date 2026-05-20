## Why

Urban 称重记录需进入 UrbanManagement 供监管与查询。本 slice 打通客户端上传与服务端持久化 API，契约以 **WeighingRecord** 为核心。

## What Changes

**MaterialClient（Urban 宿主）**

- 实现 **`IUrbanUploadService`**：轮询或事件驱动上传 `SyncPending` 记录。
- HTTP 客户端调用 UrbanManagement `POST /api/urban/weighing-records`（路径以 design 为准）。
- 成功/失败更新本地同步状态；失败写日志并依赖重试配置。

**UrbanManagement**

- 新增实体 **`UrbanWeighingRecord`**（或等价）及 EF 配置、迁移。
- 应用服务 **`UrbanWeighingRecordAppService`**：接收 DTO、校验、入库。
- 可选：管理端 LayUI/API 分页查询最近上传记录（最小列表即可）。

## Capabilities

### New Capabilities

- `urban-weighing-record-upload`: 客户端上传 + 服务端接收与存储 WeighingRecord DTO。

### Modified Capabilities

- 无（新 API 域）

## Impact

| 范围 | 说明 |
|------|------|
| **子仓库** | MaterialClient + UrbanManagement（跨仓库） |
| **依赖** | slice 01、02 |
| **安全** | 首期无登录；请求带 `DeviceId`、可选 `X-Device-Key` 配置预留 |
