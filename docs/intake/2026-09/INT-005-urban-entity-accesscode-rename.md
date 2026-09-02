# INT-005-urban-entity-accesscode-rename

| 字段 | 值 |
|------|-----|
| id | INT-005 |
| slug | urban-entity-accesscode-rename |
| title | Urban Entity 域内 BuildLicenseNo 统一为 AccessCode |
| status | open |
| kind | tech-debt |
| theme | urban-weighing |
| intake_month | 2026-09 |
| priority | P2 |
| parked_until | |
| repos | UrbanManagement, MaterialClient |
| created | 2026-09-02 |
| source | entity 语义化调研决策 D8 挂起 / docs/2026-09-02-urbanmanagement-entity-semantic-analysis |
| github | |

## 摘要

UrbanManagement（及 MaterialClient）域内接入码字段仍混用 `BuildLicenseNo` 与 `GovProject.AccessCode`。本 initiative（entity 语义化 refactor）已决定 **挂起** 全部 AccessCode 重命名与 DB 列迁移；政府第三方 API 仍使用 `buildLicenseNo` JSON 键，边界转换层单独维护。待当前 SyncStatus / ProId / SiteType 等 change 完成后，再开独立 OpenSpec 执行：Entity/DTO 统一 `AccessCode`、物理 rename 列、MaterialClient 对齐；**不**改 outbound `GovSyncWeightPayload` 的 wire 形状。

## 证据

- [`docs/2026-09-02-urbanmanagement-entity-semantic-analysis/05-AccessCode统一变动清单.md`](../../2026-09-02-urbanmanagement-entity-semantic-analysis/05-AccessCode统一变动清单.md) — 详细变动、边界、验收（权威明细）
- [`docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md`](../../2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md) — D4/D7/D8
- [`docs/2026-09-02-urbanmanagement-entity-semantic-analysis/03-业务语义化缺口.md`](../../2026-09-02-urbanmanagement-entity-semantic-analysis/03-业务语义化缺口.md) — §1.1

## 依赖

- 建议在本 initiative P0–P2 change 归档后再 propose
- 无硬依赖 INT

## 孵化记录

- 2026-09-02 登记（open）：自 entity 语义化 initiative 挂起项 promote
- 2026-09-02 补充明细：`05-AccessCode统一变动清单.md`（域内 rename / 协议保留 / 分阶段 A–D）

## 消化后回填

| 字段 | 值 |
|------|-----|
| absorbed_into | |
| change | `rename-buildlicenseno-to-accesscode`（预期） |
