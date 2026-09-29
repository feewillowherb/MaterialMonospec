## Why

现场地磅/旧客户端仍向 `POST /Api/Post` 上报萧山形状报文，而 UrbanManagement 的 `LegacyApiController` / `LegacyGovSyncAppService` 目前仅为 WIP（HTTP 501），无法落入现代权威表 `UrbanWeighingRecord`。同机 XiaoShanServe 若继续本地落盘并出站，会与 UM Worker 双报政府。需要立刻实装 Legacy 入站转换（消化 [INT-006](../../../docs/intake/2026-09/INT-006-legacy-gov-sync-reimplementation.md)），权威只写 UM。

调研权威：[docs/2026-09-03-xiaoshanserve-forward-to-urban-weighing-record/](../../../docs/2026-09-03-xiaoshanserve-forward-to-urban-weighing-record/00-调研总览.md)（D1–D12）。历史批迁 **不在本 change**（[INT-007](../../../docs/intake/2026-09/INT-007-xiaoshanserve-govsyncdata-migrate.md) 挂起）。

## What Changes

- 实装 `LegacyGovSyncAppService`：校验城管接入码 → UM 存图（全部 `AttachType.Lpr`）→ `ReceiveAsync` → `UrbanWeighingRecord`；`IngestSource = Legacy`；`ClientRecordId = Guid.NewGuid()`（不保证报文重试幂等）。
- `LegacyApiController` 保持薄门面；响应保持旧版 `{ success, msg, code }`；**不鉴权**。
- 新增 UM **拒收暂存表**（含图片 Base64，无业务索引）；拒收仍返回 `success=false`。
- 新增枚举 `UrbanWeighingIngestSource`（`Modern` / `Legacy` / `Migrated` 占位）；实体列 `IngestSource`；对外 Modern Receive 强制 `Modern`，忽略客户端伪造。
- **忽略** `fdBuildLicenseNo`；只认 `buildLicenseNo` → `AccessCode`。
- **禁止**新写 `GovSyncData`；禁止把 `sourceData` / 路径字符串写入称重实体。
- 运维切流（D11）：同机异端口，XiaoShanServe 入口 **仅 HTTP 转发**到 UM `/Api/Post`（Serve 不落盘、不做映射）；切流时停 Serve 出站（Q5）。
- **本 change 不做**：INT-007 历史批迁；MaterialClient 改协议；恢复凡东码列；`ReceiveV2`。

## Capabilities

### New Capabilities

- `urban-legacy-weighing-ingest`: Legacy `/Api/Post` 入站转换、拒收暂存、不鉴权、忽略凡东码、UM 存图(Lpr)、调用 Receive 写 `UrbanWeighingRecord`。

### Modified Capabilities

- `urban-weighing-api`: `UrbanWeighingRecord` / Receive 增加 `IngestSource`（`UrbanWeighingIngestSource`）；Modern Receive 强制 `Modern`。
- `urban-management-crud`: Legacy API 由 WIP stub 改为委托实装后的 `LegacyGovSyncAppService`（成功/拒收行为）。
- `urban-entity-sync-status`: 确认 Legacy 成功路径与拒收路径均 **不** Insert `GovSyncData`（与既有「无新插入」一致，补场景）。

## Impact

- **UrbanManagement**（Mode A，change 同名分支）：Entity/enum/migration、`LegacyGovSyncAppService`、`LegacyApiController`（AllowAnonymous）、`ReceiveAsync`/`IFileService` 衔接、单测。
- **MaterialMonospec**：OpenSpec 工件；调研夹已为输入（可随仓提交文档同步）。
- **Fdsoft.Weight.GovClient / XiaoShanServe**：本 change **无必须代码**（运维 HTTP 转发 + 停落盘/出站）；若需极薄转发配置可另记 ops，不扩转换逻辑。
- **风险**：报文重试会产生重复称重行（已接受 D6）；拒收表含 Base64 可能膨胀（临时表、无索引、可人工清理）。
