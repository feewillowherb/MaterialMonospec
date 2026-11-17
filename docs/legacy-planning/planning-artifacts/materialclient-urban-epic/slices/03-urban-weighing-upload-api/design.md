## Context

`GovSyncData` 等政府域表语义不同，**不**作为 Urban 称重主存储。`Urban_WeighingRecord` 为服务端副本表；**列级设计以 MaterialClient 本地 `WeighingRecord` 为准绳**（BMAD 不定逐列清单，见 PRD OQ-4 / `architecture.md` ADR-6）。

## Goals / Non-Goals

**Goals**

- 端到端一条记录可从客户端上传并在 UrbanManagement 查询
- 服务端表与 DTO **可对齐映射** MaterialClient 持久化的 `WeighingRecord`（实体 + EF 配置为蓝本）

**Non-Goals**

- 批量历史迁移
- OAuth / 用户登录
- 在 BMAD 中冻结与 MaterialClient 不一致的臆造列集

## Decisions

1. **表 `Urban_WeighingRecord`**：**不**在本文件列举最终列。实现阶段在 OpenSpec 中从 **`repos/MaterialClient`** 定位 `WeighingRecord` 实体及 **`UrbanManagement` 无关的** `DbContext` / `IEntityTypeConfiguration` / 迁移 SQL，**复制列定义策略**（PascalCase、类型、可空性）；表名 `Urban_WeighingRecord` 映射为 `Urban_WeighingRecord` 或项目约定前缀。允许增加：**`ReceivedAt`**（服务端 UTC）、**`RawJson`**（可选，整单备份）、**`DeviceId`**（与 `IDeviceIdentityProvider` 一致，可与业务列并存或仅存元数据列 — OpenSpec 二选一）。**幂等**：保留 **`ClientRecordId`（客户端 `WeighingRecord.Id`）+ `DeviceId`** 唯一索引（若 MaterialClient 主键名不同则在 OpenSpec 中显式映射）。
2. **API** `POST /api/urban/weighing-records`，body 为 `CreateUrbanWeighingRecordDto`（**字段集 = MaterialClient `WeighingRecord` 上传子集 + 元数据**）；幂等键见决策 1。
3. **客户端上传调度**：新建 **`AsyncPeriodicBackgroundWorkerBase` 派生类**（命名如 `UrbanWeighingUploadBackgroundWorker`），实现方式对齐 `MaterialClient/Backgrounds/PollingBackgroundService.cs`（`Timer.Period`、`DoWorkAsync`、`WithUow`）；在 UOW 内调用 `IUrbanUploadService` 扫描 **Pending** 并 `POST`；**默认周期可与主程序轮询同量级**（如 10 分钟，配置键见 `architecture.md` 示例），非固定 30s 硬编码。单条 HTTP 失败可用 Polly 重试（次数在 OpenSpec 定）。
4. **映射**：AutoMapper / 手动 Map 从 **`WeighingRecord`（MaterialClient 实体）** → DTO；DTO 中 **`DeviceId` 取自 `IDeviceIdentityProvider`**（首期即配置固定 `Guid`）。**禁止**手写与 MaterialClient 表无关的字段清单而不对照源码。
5. **查询** `GET /api/urban/weighing-records?deviceId=&page=` 供管理端；返回列与持久化实体一致。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 字段不一致 | OpenSpec 中 **列对照表** 对照 MaterialClient 源；集成测试 round-trip |
| 重复上传 | 服务端唯一索引 (DeviceId, ClientRecordId) |
| 多安装点共用同一 `FixedDeviceGuid` | 部署文档要求每现场唯一配置；**未来缓解**见 PRD OQ-3 / ADR-9 |
| MaterialClient `WeighingRecord` 演进导致 Urban 表落后 | 变更同步更新 OpenSpec + Urban 迁移；ADR-6 原则 |
