# INT-002-xiaoshan-upload-config-sync-version

| 字段 | 值 |
|------|-----|
| id | INT-002 |
| slug | xiaoshan-upload-config-sync-version |
| title | 上报配置同步、version 与变更日志 |
| status | open |
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

双端配置须保持一致：运行时仅用单调递增的 `configVersion` 裁决（高 version 胜；客户端落后则拉取服务端覆盖本地）。配置每次变更须留审计日志（谁/哪端/何时/改了什么/关联 version）；日志不替代 version 裁决。

## 证据

- `docs/intake/2026-08/drafts/archive/2026-08-27-urban-xiaoshan-upload-config.md`
- `docs/2026-08-27-xiaoshan-weighbridge-gate-product-upload-design/01-设计稿.md`

## 依赖

- INT-001

## 孵化记录

- 2026-08-27 登记（open），由 draft promote；决策 D2/D3/D5（原临时号 INT-005，同日重排为 INT-002）

## 消化后回填

| 字段 | 值 |
|------|-----|
| absorbed_into | |
| change | |
