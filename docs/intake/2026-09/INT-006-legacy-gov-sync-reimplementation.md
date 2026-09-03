# INT-006-legacy-gov-sync-reimplementation

| 字段 | 值 |
|------|-----|
| id | INT-006 |
| slug | legacy-gov-sync-reimplementation |
| title | Legacy 政务称重 HTTP 路径重构（替代 WIP 占位） |
| status | open |
| kind | tech-debt |
| theme | gov-sync |
| intake_month | 2026-09 |
| priority | P2 |
| parked_until | |
| repos | UrbanManagement |
| created | 2026-09-02 |
| source | entity 语义化调研 / Legacy 移除决策 |
| github | |

## 摘要

旧版 Legacy HTTP 入站（`LegacyApiController`、`LegacyGovSyncAppService`、`GovSyncData` 双写等）在 entity 语义化 initiative 中 **移除业务实现**，端点标记 **WIP**、**不入库**。后续需按 Modern 路径（`UrbanWeighingRecord` + 附件）重新设计并实现兼容层，而非恢复 `UrbanWeighingRecord` + `GovSyncData` 双写。

## 证据

- [`docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md`](../../2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md) — D18、D19
- `repos/UrbanManagement/src/UrbanManagement.Core/Services/LegacyGovSyncAppService.cs`
- `repos/UrbanManagement/src/UrbanManagement.App/Controllers/LegacyApiController.cs`

## 依赖

- entity 语义化 initiative 中 Legacy stub/WIP 落地后再消化

## 孵化记录

- 2026-09-02 登记（open）
- 2026-09-03 同机入站调研：[`docs/2026-09-03-xiaoshanserve-forward-to-urban-weighing-record/`](../../2026-09-03-xiaoshanserve-forward-to-urban-weighing-record/00-调研总览.md)
- 2026-09-03 **已确认**：转换业务核心在 `LegacyGovSyncAppService`（Controller 仅门面；禁 Serve 侧重做映射；禁 GovSyncData 双写）
- 2026-09-03 **新增**：`UrbanWeighingIngestSource`（Modern/Legacy/Migrated）区分入站；见调研夹 `05`
- 2026-09-03 历史批迁（原 D5/06）**挂起**为 [INT-007](./INT-007-xiaoshanserve-govsyncdata-migrate.md)；不在本 INT 实现范围

## 消化后回填

| 字段 | 值 |
|------|-----|
| absorbed_into | |
| change | |
