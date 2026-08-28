# INT-003-xiaoshan-upload-modes-field-mapping

| 字段 | 值 |
|------|-----|
| id | INT-003 |
| slug | xiaoshan-upload-modes-field-mapping |
| title | 萧山三模式多选与字段映射 |
| status | proposed |
| kind | product |
| theme | xiaoshan-upload |
| intake_month | 2026-08 |
| priority | P1 |
| parked_until | 2026-09 |
| repos | MaterialClient, UrbanManagement |
| created | 2026-08-27 |
| source | draft promote / 2026-08-27 |
| github | |

## 摘要

Urban 支持设计稿三种上报模式 Weighbridge / Gate / Product：**可多选**，默认选中 Weighbridge。各模式可配 `deviceID`、`siteType`、`inOutType`；其余字段来自称重流水或静态配置。非必填且无数据源时可跳过，须在上报路径与配置 UI 标注，不阻断主流程。

## 证据

- `docs/intake/2026-08/drafts/archive/2026-08-27-urban-xiaoshan-upload-config.md`
- `docs/2026-08-27-xiaoshan-weighbridge-gate-product-upload-design/01-设计稿.md`（三通道 Weighbridge/Gate/Product）

## 依赖

- INT-001

## 孵化记录

- 2026-08-27 登记（open），由 draft promote；决策 D4（原临时号 INT-006，同日重排为 INT-003）
- 2026-08-27 absorbed → `_bmad-output/planning-artifacts/xiaoshan-platform-upload-epic/`（脚手架 S）

## 消化后回填

| 字段 | 值 |
|------|-----|
| absorbed_into | `_bmad-output/planning-artifacts/xiaoshan-platform-upload-epic/` |
| change | `openspec/changes/add-xiaoshan-upload-modes-field-mapping` |
