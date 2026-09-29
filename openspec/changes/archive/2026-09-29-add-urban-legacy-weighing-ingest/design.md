## Context

- `LegacyApiController` + `LegacyGovSyncAppService` 现为 WIP（501），与 XiaoShanServe `POST /Api/Post` 同路由形。
- 权威称重表为 `UrbanWeighingRecord`；禁止新写 `GovSyncData`（D19）。
- 调研决策 D1–D12：`docs/2026-09-03-xiaoshanserve-forward-to-urban-weighing-record/`。
- Traits：`type-owned-methods`、`minimal-di`、`no-database-fk`、`openspec-git-workflow` Mode A。

## Goals / Non-Goals

**Goals:**

- Legacy 报文成功落入 `UrbanWeighingRecord` + Lpr 附件；`IngestSource=Legacy`。
- 校验失败写入拒收暂存（含 Base64），旧版失败响应。
- `/Api/Post` 不鉴权；忽略 `fdBuildLicenseNo`。
- 同机异端口切流由运维 HTTP 转发完成（Serve 无转换代码）。

**Non-Goals:**

- INT-007 历史批迁（`Migrated` 枚举值仅占位）。
- XiaoShanServe 内映射/落盘/出站改造（仅运维转发说明）。
- MaterialClient Modern Receive 线格式（已有 `fix-urban-weighing-receive-legacy-compat`）。
- 恢复 UM `FdBuildLicenseNo` 列。

## Decisions

### D1 — 转换只在 `LegacyGovSyncAppService`

- Controller：解析 `JsonElement` → `LegacyGovSyncRequestInputDto`；映射 `LegacyGovSyncOutputDto` → JSON；`[AllowAnonymous]`。
- Service：校验、存图、Receive、拒收暂存。
- 备选（否决）：Serve 内转换；Controller 内映射。

### D2 — 成功路径：FileService(Lpr) → ReceiveAsync

```text
buildLicenseNo → GovProject.AccessCode → ProId/ProName
grossWeight>0 覆盖 goodsWeight → TotalWeight (kg)
siteType "1"/"2" → UrbanSiteType
snapImages → SaveAndCompress*(AttachType.Lpr) → AttachmentIds
ClientRecordId = Guid.NewGuid()
IngestSource = Legacy
→ ReceiveAsync
```

- 重量优先级对齐历史 XiaoShanServe。
- 映射用 static / type-owned（如 `UrbanSiteType` 解析、`UrbanWeighingRecordReceiveInputDto` 工厂）；**禁止** MappingService。

### D3 — `IngestSource` 枚举与防伪

```csharp
enum UrbanWeighingIngestSource { Modern = 0, Legacy = 1, Migrated = 2 }
```

- 实体 non-nullable，默认 `Modern`；migration 存量行 = 0。
- Modern `ReceiveAsync`：**忽略**入参伪造，强制写 `Modern`。
- 仅 Legacy Service 构造路径写 `Legacy`。
- `Migrated` 本 change 不写入业务路径。

### D4 — `ClientRecordId` 方案 A

- Legacy 每次 `Guid.NewGuid()`；接受重试重复行。
- 与批迁 `Guid.Empty`（INT-007）分离；本 change 不实现 Empty 插入。

### D5 — 拒收暂存表

- 实体建议名 `LegacyWeighingRejectStaging`；仅 PK 索引；Base64 单列 JSON（`SnapImagesBase64Json`）。
- 触发：无城管码、项目未找到、解析失败、Receive 前失败等。
- 成功路径不写；响应仍 `success=false`。
- Repository 可注册（有 I/O）；禁止纯映射 DI。

### D6 — 忽略凡东码

- 不读、不换码 `fdBuildLicenseNo`；仅 `buildLicenseNo` → AccessCode。

### D7 — 切流（运维）

- Client → Serve:{portA}/Api/Post → HTTP forward → UM:{portB}/Api/Post。
- Serve 禁止落盘/写 GovSyncData/出站；本 change 代码仓以 UM 为主。

### D8 — Git Mode A

- `UrbanManagement`（及 monospec 文档若改）change 同名分支 → squash 入 trunk。

## Risks / Trade-offs

- [重试重复行] → 已接受；运维可人工清理。
- [拒收表膨胀] → 临时表、无业务索引、可手工删；不进正式列表。
- [转发层误落盘] → 验收禁止 Serve TempUpload 新文件。
- [Filtered unique vs Empty] → 本 change 不引入 Empty ClientRecordId 行。

## Migration Plan

1. 部署 UM（enum 列 + 拒收表 + Legacy 实装 + AllowAnonymous）。
2. 配置同机转发；停 Serve 出站与落盘。
3. 用样例报文（城管码 + base64）打 Serve 端口验证 UM 入库。
4. 回滚：还原 Legacy stub 501 + 去掉新表/列（数据需备份）。

## Open Questions

- Q5：切流当日停 Serve `ExplortStatisticBgService`（默认是）。
- Q8/Q10：采用默认命名与 Receive 防伪（见上）。
