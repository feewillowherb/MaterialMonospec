## Context

客户端 `add-urban-passage-record` 已本地入库进出，明确不上报。UrbanManagement `GovSyncManager` 只处理 `UrbanWeighingRecord`，`IGovSyncHttpClient` `[Post("")]` 打历史场地 save，payload 混地磅与卡口字段且 `InOutType` 写死 0。研究笔记：`docs/2026-08-28-urbanmanagement-passage-xiaoshan-upload/`（Q1–Q5 已决）。

约束：`type-owned-methods`、`minimal-di`、`no-database-fk`、`viewmodel-no-repository`；UM 接口与实现同文件、`[AutoConstructor]`；禁止 tuple。Git Mode A。

## Goals / Non-Goals

**Goals:**

- 客户端进出上云到 UM；UM 独立进出表；卡口/成品两条 Receive 与两个列表页。
- UM 出站三通道独立实现：地磅 `lantu/saveRecord`，卡口/成品 `inoutRecord/save`（成品 `L-02`）。
- Converter 仅出站；Gov host 在 UM 配置。

**Non-Goals:**

- 心跳；进出审批/异常；第二张成品同构表；客户端直连萧山；BasePlatform；改管线 Graph。
- 把 Converter / 映射注册为 Service。

## Decisions

### 1. 分流键与独立代码（Q2/Q3）

分流用记录种类：来自 LPR 卡口 / 来自 LPR 成品 / 地磅 Receive。平台看 `buildLicenseNo` 有无 `-02`。UM 卡口与成品 ApplicationService、出站 payload `record`、Converter、Worker 调用、Blazor 页 **各写一套，允许重复**。禁止一个方法 `if (source)` 共用。进出表仍一张 + `PassageSource`。

**备选**：共用 Receive + 判别字段 → 拒绝。共用 Refit 方法再拼后缀 → 拒绝（URL 相同不是合并 C# 的理由）。

### 2. 实体与 Receive

UM `UrbanPassageRecord` 挂 `UrbanManagementDbContext`，独立 migration。列对齐客户端（无重量）。`FromClientDto(...)` 类型归属工厂。两个 AppService（如 `UrbanCheckpointPassageAppService` / `UrbanFinishedProductPassageAppService`），写操作 `[UnitOfWork]`。附件复用 `upload-multipart`，逻辑 Id。

客户端：`SubmitRecordAsync` 对 `PassageSource` 分叉调两个 API；地磅仍 `ReceiveWeighingRecordAsync`。

### 3. 页面

两个 Blazor（或现网等价）页：过滤 `Checkpoint` / `FinishedProduct`。列：车牌（「无」→「未识别」）、颜色、车型、进出、场地、抓拍时间、大图、上报状态。View 只调 AppService，禁止 Repository/DbContext。

### 4. 出站 payload 与 Converter（Q1/Q4）

命名 `record`：`XiaoshanWeighbridgeSaveRecord`、`XiaoshanCheckpointSaveRecord`、`XiaoshanProductSaveRecord`。各 `From*(entity, context)` 委托该通道 Converter。

| 领域 | 地磅 | 卡口 Converter | 成品 Converter |
|------|------|----------------|----------------|
| Enter | `inOutType` `0` | `deviceID` `01` | 同码表、独立类型 |
| Exit | `1` | `02` | 同左 |
| Construction / Disposal | 地磅若有同类字段则转 | `siteType` `1`/`2` | 独立类型 |

`dataSource` 常量 `WEIGHBRIDGE_XIAOSHAN`。卡口/成品不得写 `dataSource`。进出 `goodsWeight` 缺省省略，禁止填 0。`XiaoshanBuildLicenseNo.ForProduct` 只拼一次。Helper 为 static，不注册 DI。

删除 `GovSyncWeightPayload.FromRecord` 写死进。称重 `carType` 可沿用现网吨位规则或实体已有车型；进出用快照 `VehicleType`。

### 5. HTTP 与 Worker

三个 Refit 接口或三个 `[Post]` 路径：`/sapi/v1/inoutRecord/lantu/saveRecord`、卡口 save、成品 save（成品可重复卡口接口定义）。`BaseAddress` 来自 UM 配置的 Gov host（Q5）；默认共用；可配第二 host。成功：`code == 200`。

Worker：称重 pending 仍扫 `UrbanWeighingRecord`（排除异常等现网规则）但 **调用地磅 Client**。卡口 pending / 成品 pending **各自**查询进出表 + `PassageSource` + 同步状态字段（与称重对称的 SyncType/RetryCount 或等价命名 `record` 状态）。禁止一个 `ProcessRecordAsync` 内 if 三种源。

进出行关联项目：逻辑 `ProId`/`BuildLicenseNo` 从同一项目配置读取，禁止跨 Context FK。

### 6. 客户端附件

进出上云前按 `urban-client-attachment-sync` 上传大图/小图（有则传），把 Guid 写入对应 Receive DTO。

## Risks / Trade-offs

- [重复代码] → 接受（对齐平台两套实现）；禁止抽「带后缀参数」的共用出站。
- [现网称重已错误打 save] → 地磅切 `lantu/saveRecord` 可能暴露历史 payload 问题；用 Converter + 恒定 `dataSource` 对齐 SyncDoc。
- [混合 host] → 默认一 host；配置第二地址覆盖地磅或场地。

## Migration Plan

先 UM 表与 API，再客户端上云，再切 Worker 三通道（称重切 path 与进出出队可同发）。回滚：停 Worker 进出出队；客户端改回只称重 Receive；表可留。

## Open Questions

无。
