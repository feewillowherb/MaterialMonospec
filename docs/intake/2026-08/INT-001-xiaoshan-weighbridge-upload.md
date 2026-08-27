# INT-001-xiaoshan-weighbridge-upload

| 字段 | 值 |
|------|-----|
| id | INT-001 |
| slug | xiaoshan-weighbridge-upload |
| title | 萧山地磅称重结果上报 |
| status | open |
| kind | product |
| theme | xiaoshan-upload |
| intake_month | 2026-08 |
| priority | P1 |
| parked_until | 2026-09 |
| repos | UrbanManagement |
| created | 2026-08-27 |
| source | 设计稿整理 / 2026-08-27 |
| github | |

## 摘要

向萧山渣土监管平台上报地磅称重结果。使用专用接口 `POST /sapi/v1/inoutRecord/lantu/saveRecord`；不做地磅心跳。实现侧预期落在 UrbanManagement / 既有 GovSync 链路。

## 证据

- `docs/2026-08-27-xiaoshan-weighbridge-gate-product-upload-design/01-设计稿.md` §3
- `docs/SyncDoc/地磅数据上传对接接口（萧山）V1.0.md`

## 依赖

- 无

## 孵化记录

- 2026-08-27 登记（open），自设计稿拆出种子

## 消化后回填

| 字段 | 值 |
|------|-----|
| absorbed_into | |
| change | |
