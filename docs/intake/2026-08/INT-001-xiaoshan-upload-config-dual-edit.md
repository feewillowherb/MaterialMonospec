# INT-001-xiaoshan-upload-config-dual-edit

| 字段 | 值 |
|------|-----|
| id | INT-001 |
| slug | xiaoshan-upload-config-dual-edit |
| title | 萧山上报配置模型与双端编辑 |
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

`MaterialClient.Urban` 需要上传配置能力，且 `UrbanManagement` 也能改同一套配置。双端均可编辑；**服务端为权威**（客户端改动须回写并对齐服务端后才算生效）。

## 证据

- `docs/intake/2026-08/drafts/archive/2026-08-27-urban-xiaoshan-upload-config.md`
- `docs/2026-08-27-xiaoshan-weighbridge-gate-product-upload-design/01-设计稿.md`

## 依赖

- 无（本条为配置能力底座；INT-002/003/004 依赖本条）

## 孵化记录

- 2026-08-27 登记（open），由 draft promote；决策 D1（原临时号 INT-004，同日重排为 INT-001）
- 2026-08-27 absorbed → `_bmad-output/planning-artifacts/xiaoshan-platform-upload-epic/`（脚手架 S）
- 2026-08-27 proposed → `openspec/changes/add-xiaoshan-upload-config-dual-edit`

## 消化后回填

| 字段 | 值 |
|------|-----|
| absorbed_into | `_bmad-output/planning-artifacts/xiaoshan-platform-upload-epic/` |
| change | `openspec/changes/add-xiaoshan-upload-config-dual-edit` |
