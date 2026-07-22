## Context

归档变更 `materialclient-recycle-enhancement` 已落地 `RecycleWaybillExtension`（按 `WaybillId`）与 UI 单价/合同号录入，但 `UpdateRecycleModeAsync` 仅在 `ItemType=Waybill` 时 upsert 扩展表。未配对 `WeighingRecord` 阶段无暂存；匹配建单（`CreateWaybillAsync`）也不拷贝 Recycle 字段。SolidWaste 已通过 `SolidWasteInfoExtensions` + `CopySolidWasteInfoToWaybill` 覆盖「运单前暂存 → 建单拷贝」全链路，本变更对齐该模式。

约束：ViewModel 不直连 Repository；Service 写库用 `[UnitOfWork]`；禁止 tuple API；OpenSpec 仅在主仓库。

## Goals / Non-Goals

**Goals:**

- WeighingRecord 阶段持久化/回填 `UnitPrice`、`SaleContractNo`（ExtraProperties）
- 匹配建单时拷贝到 `RecycleWaybillExtension`
- 扩展方法风格对齐 `SolidWasteInfoExtensions`

**Non-Goals:**

- 不改 `ReceivingTime` / 收货 / §2.2 上报路径
- 不扩展 Waybill 主表，不把 Recycle 字段再写到 Waybill ExtraProperties
- 不处理历史已丢弃的编辑数据回填
- 不清理其他技术债务

## Decisions

### D1. ExtraProperties 键与扩展类（镜像 SolidWaste）

- **决策**：新建 `RecycleInfoExtensions`，键名 `RecycleInfo.UnitPrice`（`decimal?`）、`RecycleInfo.SaleContractNo`（`string?`）；仅扩展 `WeighingRecord`（Waybill 侧继续用扩展表）。
- **备选**：新建 `RecycleWeighingRecordExtension` 表（按 `WeighingRecordId`）— 拒绝：SolidWaste 已用 ExtraProperties 证明足够；两字段无需 SQL 索引。
- **备选**：把字段也写到 Waybill ExtraProperties — 拒绝：与既有 `RecycleWaybillExtension` 双写冲突。

### D2. 保存路径分层

| ItemType | 持久化目标 |
|----------|------------|
| WeighingRecord | `record.SetUnitPrice` / `SetSaleContractNo`（ExtraProperties） |
| Waybill | 既有 `UpsertRecycleExtensionAsync` → `RecycleWaybillExtension` |

- null 入参 SHALL 置空对应键/列（与 Waybill 分支一致）。

### D3. 建单拷贝：`CopyRecycleInfoToWaybillExtensionAsync`

- **调用点**：`WeighingMatchingService.CreateWaybillAsync`，紧邻 `CopySolidWasteInfoToWaybill`。
- **策略**：join 记录优先，缺失则 fallback 到 out 记录（同 SolidWaste）；upsert 扩展行（`UnitPrice`/`SaleContractNo`；`ReceivingTime` 保持 null）。
- **依赖**：`WeighingMatchingService` 注入 `IRepository<RecycleWaybillExtension, Guid>`，或抽取共享 upsert helper 供 Matching 与 `RecycleWeighingService` 复用（实现时择一，优先小改：Matching 内联 upsert 或调用可复用静态/内部方法）。

### D4. UI 回填

- WeighingRecord：`GetUnitPrice()` / `GetSaleContractNo()`
- Waybill：继续读 `RecycleWaybillExtension`（不变）

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| Matching 与 RecycleWeighingService 两处 upsert 逻辑漂移 | 单测覆盖两边；可选抽共享 helper |
| join/out 两边都有不同单价 | join-first + out-fallback（文档化；与 SolidWaste 一致） |
| ExtraProperties JSON 不可索引 | 可接受：仅 UI 暂存，查询按主键 |

## Migration Plan

- 无 EF 迁移；部署新客户端即可。
- 回滚：还原代码；已写入 ExtraProperties 的键无害留存。
- 历史未暂存数据无法恢复。

## Open Questions

无（决策已对齐 SolidWaste 先例与用户反馈）。
