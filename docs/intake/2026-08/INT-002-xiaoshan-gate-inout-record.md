# INT-002-xiaoshan-gate-inout-record

| 字段 | 值 |
|------|-----|
| id | INT-002 |
| slug | xiaoshan-gate-inout-record |
| title | 萧山卡口车辆进出记录上报 |
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

向萧山平台上报场地出入口车辆抓拍进出记录（卡口）。接口 `POST /sapi/v1/inoutRecord/save`；`buildLicenseNo` 使用平台颁发的原值 `L`。

## 证据

- `docs/2026-08-27-xiaoshan-weighbridge-gate-product-upload-design/01-设计稿.md` §4
- `docs/SyncDoc/杭州市工程渣土监管服务平台场地数据接口（萧山）V1.0.md`
- `docs/gov-sync-postweight-analysis.md`（同路径族联调参考）

## 依赖

- 无

## 孵化记录

- 2026-08-27 登记（open），自设计稿拆出种子

## 消化后回填

| 字段 | 值 |
|------|-----|
| absorbed_into | |
| change | |
