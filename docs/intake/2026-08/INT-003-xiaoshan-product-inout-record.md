# INT-003-xiaoshan-product-inout-record

| 字段 | 值 |
|------|-----|
| id | INT-003 |
| slug | xiaoshan-product-inout-record |
| title | 萧山成品进出记录上报（buildLicenseNo 后缀 -02） |
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

成品与卡口共用 `POST /sapi/v1/inoutRecord/save` 与相同请求体；业务区分仅为 `buildLicenseNo` 在原值后拼接 `-02`（例：卡口 `330106202212120101` → 成品 `330106202212120101-02`）。

## 证据

- `docs/2026-08-27-xiaoshan-weighbridge-gate-product-upload-design/01-设计稿.md` §5
- `docs/SyncDoc/杭州市工程渣土监管服务平台场地数据接口（萧山）V1.0.md`

## 依赖

- INT-002（同接口族；实现时可同 change 或同 slice，消化时再定）

## 孵化记录

- 2026-08-27 登记（open），自设计稿拆出种子

## 消化后回填

| 字段 | 值 |
|------|-----|
| absorbed_into | |
| change | |
