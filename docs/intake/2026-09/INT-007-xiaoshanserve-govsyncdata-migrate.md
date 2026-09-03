# INT-007-xiaoshanserve-govsyncdata-migrate

| 字段 | 值 |
|------|-----|
| id | INT-007 |
| slug | xiaoshanserve-govsyncdata-migrate |
| title | XiaoShanServe Gov_SyncData 历史批迁至 UrbanWeighingRecord |
| status | open |
| kind | ops |
| theme | xiaoshan-upload |
| intake_month | 2026-09 |
| priority | P2 |
| parked_until | 2026-09 |
| repos | UrbanManagement；现场 XiaoShanServe 库/文件只读 |
| created | 2026-09-03 |
| source | 调研夹 06 / 用户确认挂起批迁 |
| github | |

## 摘要

同机切流后，需把 XiaoShanServe 已入库的 `Gov_SyncData`（及抓拍图）批迁到 UM `UrbanWeighingRecord`。已确认方向：丢弃 `sourceData`、目标主键重生成、批迁 `ClientRecordId=Guid.Empty`、`IngestSource=Migrated`、已政府成功行标 `Success` 防双报。**本期挂起**，不进入当前在线 Legacy / INT-006 实现范围。

## 证据

- [`docs/2026-09-03-xiaoshanserve-forward-to-urban-weighing-record/06-XiaoShanServe历史数据迁移.md`](../../2026-09-03-xiaoshanserve-forward-to-urban-weighing-record/06-XiaoShanServe历史数据迁移.md)
- [`docs/2026-09-03-xiaoshanserve-forward-to-urban-weighing-record/00-调研总览.md`](../../2026-09-03-xiaoshanserve-forward-to-urban-weighing-record/00-调研总览.md)（D5）

## 依赖

- INT-006（在线 Legacy→Receive）可先于本 INT；批迁建议独立 change
- UM `GovProject.AccessCode` 与源对接码对齐

## 孵化记录

- 2026-09-03 调研写入 06；用户确认挂起 → 登记本 INT（open，`parked_until=2026-09`）

## 消化后回填

| 字段 | 值 |
|------|-----|
| absorbed_into | |
| change | |
