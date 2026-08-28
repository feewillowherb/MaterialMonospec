# INT-004-xiaoshan-upload-legacy-client-compat

| 字段 | 值 |
|------|-----|
| id | INT-004 |
| slug | xiaoshan-upload-legacy-client-compat |
| title | 萧山上报配置旧客户端兼容 |
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

现场并非所有客户端都能及时升级。服务端/协议须兼容旧客户端（缺字段、不懂新模式、不上报 version 等）并提供降级路径，不能因新配置协议直接不可用。消化时需明确最低兼容版本、旧端读到新配置的默认行为、以及是否禁止旧端回写覆盖新字段。

## 证据

- `docs/intake/2026-08/drafts/archive/2026-08-27-urban-xiaoshan-upload-config.md`

## 依赖

- INT-001
- 相关：INT-002、INT-003

## 孵化记录

- 2026-08-27 登记（open），由 draft promote；决策 D6（原临时号 INT-007，同日重排为 INT-004）
- 2026-08-27 absorbed → `_bmad-output/planning-artifacts/xiaoshan-platform-upload-epic/`（脚手架 S）

## 消化后回填

| 字段 | 值 |
|------|-----|
| absorbed_into | `_bmad-output/planning-artifacts/xiaoshan-platform-upload-epic/` |
| change | `openspec/changes/add-xiaoshan-upload-legacy-client-compat` |
