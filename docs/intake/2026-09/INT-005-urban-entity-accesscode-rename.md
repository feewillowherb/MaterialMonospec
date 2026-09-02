# INT-005-urban-entity-accesscode-rename

| 字段 | 值 |
|------|-----|
| id | INT-005 |
| slug | urban-entity-accesscode-rename |
| title | Urban Entity 流水表 BuildLicenseNo 固化为 AccessCode |
| status | proposed |
| kind | tech-debt |
| theme | urban-weighing |
| intake_month | 2026-09 |
| priority | P2 |
| parked_until | |
| repos | UrbanManagement |
| created | 2026-09-02 |
| source | entity 语义化调研决策 D8 挂起 / docs/2026-09-02-urbanmanagement-entity-semantic-analysis |
| github | |

## 摘要

仅将 UrbanManagement **Entity**（`UrbanWeighingRecord` / `UrbanPassageRecord` / `GovSyncData`）上的接入码属性与 DB 列由 `BuildLicenseNo` 固化为 `AccessCode`，与已完成的 `GovProject.AccessCode` 对齐。DTO / API / MaterialClient / 政府·JWT·Hub wire **不在本 INT**；边界继续 `dto.BuildLicenseNo` ↔ `entity.AccessCode`。

## 证据

- [`docs/2026-09-02-urbanmanagement-entity-semantic-analysis/05-AccessCode统一变动清单.md`](../../2026-09-02-urbanmanagement-entity-semantic-analysis/05-AccessCode统一变动清单.md) — 收敛范围与验收（权威明细）
- [`docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md`](../../2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md) — D4/D7/D8
- [`docs/2026-09-02-urbanmanagement-entity-semantic-analysis/03-业务语义化缺口.md`](../../2026-09-02-urbanmanagement-entity-semantic-analysis/03-业务语义化缺口.md) — §1.1

## 依赖

- 无硬依赖 INT（entity-semantic P0–P2 已归档）

## 孵化记录

- 2026-09-02 登记（open）：自 entity 语义化 initiative 挂起项 promote
- 2026-09-02 补充明细：`05-AccessCode统一变动清单.md`
- 2026-09-02 **收敛**：仅 UM Entity + 列 rename；剔除 MC / DTO / wire（见 05）
- 2026-09-02 **proposed**：`openspec/changes/rename-urban-entity-buildlicenseno-to-accesscode`

## 消化后回填

| 字段 | 值 |
|------|-----|
| absorbed_into | rename-urban-entity-buildlicenseno-to-accesscode |
| change | `rename-urban-entity-buildlicenseno-to-accesscode` |
