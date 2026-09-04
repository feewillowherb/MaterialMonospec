## Why

近期 UrbanManagement 实体语义化将 `ReceiveAsync` 入参收紧为强类型 `SyncStatus` / `UrbanSiteType` 等后，**已部署的旧版 MaterialClient.Urban** 提交称重记录时在模型绑定阶段 400（无法反序列化枚举 / `input` 为空），无法入库。需要立刻把 **`ReceiveAsync` 的入站线格式回滚为旧客户端可提交的宽松契约**；强类型落库与出站逻辑保留。新客户端专用的 `ReceiveV2` **本 change 不做**。

## What Changes

- **`ReceiveAsync` 入参线格式回滚（兼容旧客户端）**：`UrbanWeighingRecordReceiveInputDto`（及若仍暴露的同形 App DTO）对旧客户端仍在使用的字段恢复宽松绑定——至少包括：
  - `siteType`：接受历史 string / 数字 wire（如 `"1"`/`"2"`、枚举名、可识别别名），缺省 → `Construction`
  - `syncType` / `clientSyncType`：接受 int / 可空 / 字符串名；客户端 `Synced(1)` 与服务端 `Success(1)` 按 ordinal 对齐；缺省 → `Pending`
  - `clientRetryCount` 等近期收紧的可空性：恢复旧客户端可省略的形态
- **Service 内映射**：宽松入参 → 现有实体强类型（`UrbanSiteType` / `SyncStatus` / required `ProId` 等）；**不**回滚表结构或实体 enum 列。
- **路由与方法名不变**：仍为现有 ABP 约定 `POST .../urban-weighing-record/receive` → `ReceiveAsync`；旧客户端无需改 URL。
- **明确不做**：`ReceiveV2`（及新客户端专用契约）、通行 `passage/receive` 线格式改造、MaterialClient 强制升级、Legacy `/Api/Post`（INT-006）实装。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `urban-weighing-api`: `ReceiveAsync` 入站 DTO/绑定恢复旧客户端兼容；持久化与幂等语义不变；声明 `ReceiveV2` 为后续、本 change 不交付。

## Impact

- **UrbanManagement**：`UrbanWeighingRecordReceiveInputDto`（及对齐的 App 模型若共用）、`UrbanWeighingRecordAppService.ReceiveAsync` 映射、相关单测；Git **Mode A**（change 同名分支 → squash 入 trunk）。
- **MaterialClient / FdSoft.BasePlatform**：无必须改动（以服务端兼容旧包为主）。
- **风险**：宽松绑定后非法 `siteType` 需有明确默认/拒绝策略（见 design）；勿把宽松类型泄漏到实体或出站 payload。
