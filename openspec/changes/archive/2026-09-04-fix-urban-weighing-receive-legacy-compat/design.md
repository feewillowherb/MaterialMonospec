## Context

`dev-urban-entity-semantic` 系列已将 `UrbanWeighingRecord` 持久化层的 `SiteType` / `SyncType` / `ClientSyncType` 收紧为领域 enum，并把 **`ReceiveAsync` 入参 DTO** 同步改成 `UrbanSiteType` / `SyncStatus`。现场旧版 MaterialClient.Urban 仍按历史线格式提交（`siteType` 多为 `"1"`/`"2"` 或自由文本；`syncType`/`clientSyncType` 多为 int 或客户端名 `Synced`），在 ASP.NET 模型绑定阶段失败（`AbpValidationException`，`input` 为空），附件 multipart 虽成功但 Receive 落库失败。

约束：实体与出站强类型 **不回滚**；仅修复 `ReceiveAsync` 入站兼容；`ReceiveV2` 明确延后；遵循 `type-owned-methods` / `minimal-di`（映射用 static / 类型归属方法，禁止新建 MappingService）。

## Goals / Non-Goals

**Goals:**

- 旧客户端对现有 `POST /api/app/urban-weighing-record/receive` 能再次成功绑定并入库。
- 入站宽松值在 Service 边界内规范化为现有实体 enum / Guid 规则。
- `ProId` 仍拒绝空 / `Guid.Empty`（不恢复 string ProId）。
- 幂等、`IsAnomaly`、附件关联等既有 Receive 语义不变。

**Non-Goals:**

- `ReceiveV2` / 新客户端专用契约。
- 通行记录 `passage/receive` 线格式改造。
- 回滚 EF 列类型或实体属性类型。
- 恢复 `FdBuildLicenseNo` 入参。
- MaterialClient 强制升级或改 Submit DTO（可选后续独立 change）。
- INT-006 Legacy `/Api/Post`。

## Decisions

### D1 — 只放宽 Receive 入参，不改路由/方法名

- **选择**：继续 `ReceiveAsync(UrbanWeighingRecordReceiveInputDto input)` + ABP 约定路由。
- **理由**：旧客户端 URL 与方法名已固化；改路径等于逼升级。
- **备选**：立刻引入 `ReceiveV2` 并让旧客户端继续打旧路由 —— 用户明确本 change 不做 V2。

### D2 — 入参对「易炸字段」恢复宽松 CLR / 绑定，再映射到实体

对 `UrbanWeighingRecordReceiveInputDto`（及若仍参与序列化的 `App.Models.UrbanWeighingRecordDto` 同形字段）至少：

| JSON 字段 | 宽松入参形态 | 规范化结果 |
|-----------|--------------|------------|
| `siteType` | `string?` 或可同时吃 number/string 的 JsonConverter | `UrbanSiteType`：`"2"`/`Disposal`/`消纳` → `Disposal`；`"1"`/`Construction`/`工地`/空/未知 → `Construction` |
| `syncType` / `clientSyncType` | `int?` 或 tolerant converter（int + 字符串名） | `SyncStatus`：ordinal `0/1/2`；名 `Pending`/`Success`/`Failed`；**别名 `Synced` → `Success`**；缺省 → `Pending` |
| `clientRetryCount` | `int?` | 缺省 `0` |

其余字段保持现契约（`ClientRecordId` Guid、`ProId` Guid 必填、`AttachmentIds` 等）。

- **理由**：与 enum 强化前可工作的 Receive DTO 对齐，避免 STJ 在绑定期因非法 enum token 整包失败。
- **备选**：仅挂 JsonConverter、CLR 仍为 enum —— 可做，但 `"1"`/`Synced` 仍需自定义转换；显式 `string?`/`int?` 更易测、与历史 DTO 一致。

### D3 — 映射归属：static / type-owned，禁止 MappingService

- 提供 static 解析（例如 `UrbanSiteTypeReceiveParser.Parse(string?)`、`SyncStatusReceiveParser.Parse(...)`）或挂在目标类型上的 `FromReceiveWire`。
- `UrbanWeighingRecord` 创建/更新路径：若本 change 触及 `ReceiveAsync` 内逐字段赋值，迁到实体实例方法 / `FromReceive(...)`（`type-owned-methods`）。
- **禁止** 注册 `*MappingService` / `ITransientDependency` 纯映射类型（`minimal-di`）。

### D4 — `App.Models.UrbanWeighingRecordDto` 对齐或证明无绑定路径

若该类型仍被任何 HTTP/JSON 路径反序列化，MUST 与 Core Receive 入参宽松策略一致；若已无引用，可不改但须在 tasks 中确认。

### D5 — Git Mode A

独立小修复：`UrbanManagement`（及 monospec 文档）change 同名分支，squash 入各仓 trunk。

## Risks / Trade-offs

- [未知 `siteType` 被默认为 Construction] → 出站可能变成政府 `"1"`；可接受为兼容默认；design/tests 固定映射表，日志 Debug 记原始 wire。
- [宽松绑定掩盖真正坏包] → `ProId` / `ClientRecordId` 仍硬校验；非法 JSON 结构仍 400。
- [新客户端已发 enum 名] → 映射表同时接受 `Construction`/`Disposal`，正向兼容。
- [与现行 `urban-weighing-api`「DTO 为 UrbanSiteType」条文冲突] → 本 change 用 MODIFIED 把「Receive 线格式」与「实体类型」拆开表述。

## Migration Plan

1. 部署 UrbanManagement（仅服务端即可恢复旧客户端 Receive）。
2. 用旧客户端包 + 样例 body（`siteType:"1"|"2"`、`syncType:0`、`clientSyncType:1`）回归 multipart→receive。
3. 回滚：还原 Receive DTO/映射提交即可；无 DB migration。

## Open Questions

- 现场旧包是否仍发送非 Guid 的 `proId`？当前假设否；若有，另开 change（本 change 不恢复 string ProId）。
- `ReceiveV2` 的最终形状（强类型入参）留待独立 propose，本 design 不预写 API。
