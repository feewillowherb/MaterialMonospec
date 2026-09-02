## Context

- 调研 P2 D15：`SiteType` **属性名不变**，类型 → `UrbanSiteType`；存量 string → int。
- 前置：P0/P1/`refactor-urban-proid-guid-required` 已在 `dev-urban-entity-semantic`。
- 现状：`UrbanWeighingRecord.SiteType` 为 `string?`；`UrbanPassageRecord.UrbanSiteType` 已为 enum；`GovSyncWeightPayload.SiteType` 为出站 string，现直接透传 `record.SiteType ?? "1"`。
- 约束：D5 出站协议形状不变；禁止 tuple；type-owned-methods；outbound 转换用 static converter，不注册 DI。

## Goals / Non-Goals

**Goals:**

- 称重持久化与 Receive/Submit 的 `SiteType` 统一为 `UrbanSiteType`。
- Migration 将历史 string 映射为 enum int。
- 地磅 outbound 经 converter 输出 `"1"`/`"2"`，与卡口/成品一致。

**Non-Goals:**

- `GovSyncData.SiteType` 强类型。
- `EnableSync` rename、AccessCode、VehicleType/PlateColor。
- 改变政府 HTTP 字段名或 wire 枚举值集合。

## Decisions

### 1. 属性名保留 `SiteType`

- **选择**：实体属性仍叫 `SiteType`，类型 `UrbanSiteType`；**不**改名为 `UrbanSiteType`（通行表因历史已用 `UrbanSiteType`，称重按 D15 保留短名）。
- **理由**：D15 明确；减少 Blazor/DTO 大面积 rename。

### 2. Non-nullable + 默认 Construction

- **选择**：`UrbanSiteType SiteType { get; set; } = UrbanSiteType.Construction`。
- **理由**：创建时即有业务含义；与 LPR 默认一致。

### 3. Migration 映射表

| 历史值（trim，忽略大小写） | 目标 |
|---------------------------|------|
| `1`, `construction`, `工地` | `Construction` (0) |
| `2`, `disposal`, `消纳` | `Disposal` (1) |
| NULL / 空 / 其他 | `Construction` (0) |

- **备选**：无法识别则删行 — 拒绝，称重数据不可丢。

### 4. API 序列化

- **选择**：`JsonStringEnumConverter`（已有 SyncStatus 配置）输出 `"Construction"` / `"Disposal"`。
- **理由**：与 D10 字符串 enum 策略一致；MaterialClient 同栈。

### 5. Outbound 投影

- **选择**：在 `XiaoshanWeighbridgeConverter` 增加 `SiteType(UrbanSiteType)`：`Disposal`→`"2"`，否则 `"1"`；`GovSyncWeightPayload.FromRecord` 调用之。
- **理由**：与 checkpoint/product converter 对齐；D5 协议不变。

### 6. MaterialClient 赋值

- **选择**：上云时从 Scale LPR 配置行的 `UrbanSiteType` 赋值；无可用行时 `Construction`。
- **理由**：当前恒 `null` 无法满足 non-nullable；LPR 已是权威场地语义源。

## Risks / Trade-offs

- **[Risk] 历史脏 string 一律变 Construction** → 少数错误分类；可接受，优于丢数据。
- **[Risk] API BREAKING**（string → enum JSON）→ 需同版本部署 UM + MC。
- **[Trade-off] 称重属性名 `SiteType` vs 通行 `UrbanSiteType`** → 按 D15 接受命名不对称。

## Migration Plan

1. 备份 SQLite。
2. 应用 migration（UPDATE 映射 → AlterColumn int）。
3. 同版本部署 UM + MaterialClient。
4. 回滚：restore backup。

## Open Questions

- 无阻塞项。
