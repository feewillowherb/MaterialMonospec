## Why

Urban 称重记录需进入 UrbanManagement 供监管与查询。本 slice 打通客户端上传与服务端持久化 API，契约以 **WeighingRecord** 为核心。

## What Changes

**MaterialClient.Urban（桌面端）**

- 实现 **`IUrbanUploadService`**：由 **ABP `AsyncPeriodicBackgroundWorkerBase` + `IUnitOfWorkManager`** 定周期调用（与 **`MaterialClient.Backgrounds.PollingBackgroundService`** 同类机制），在 UOW 内扫描 `SyncPending` 并上传。
- HTTP 客户端调用 UrbanManagement `POST /api/urban/weighing-records`（路径以 design 为准）。
- 成功/失败更新本地同步状态；失败写日志并依赖重试配置；Worker 周期与启用开关可配置（对齐主程序 `BackgroundServices:Polling` 思路）。
- 请求与遥测中的 **`DeviceId`** 均通过 **`IDeviceIdentityProvider`** 注入（首期固定配置 `Guid`，见 PRD FR-1.5 / ADR-9）。

**UrbanManagement**

- 新增实体 **`UrbanWeighingRecord`**（或等价）及 EF 配置、迁移；**表结构以 MaterialClient 本地 `WeighingRecord` 为蓝本**（同构或子集 + 少量服务端列），**不在 BMAD 逐列定稿** — 详见 `design.md` 决策 1 与 `architecture.md` ADR-6。
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
