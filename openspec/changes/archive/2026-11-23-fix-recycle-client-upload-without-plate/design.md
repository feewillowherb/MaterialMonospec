## Context

周期结束时 `RecycleWeighingRecordSideEffects.FinalizeWeighingCycleAsync` 已无条件把回收称重记录标为待上传，没有任何数据质量门槛。拦住磅单的是两处：客户端 `SendAsync` 的 `string.IsNullOrWhiteSpace(record.PlateNumber)` 跳过，以及服务端 `Receive` 里的 `RecycleText.Require(plateNumber, …)` 和 `gross < 0` 拒绝。

上传链路、幂等键、照片独立上传沿用 `fix-recycle-client-weighing-upload` 的设计，本单不改。

## Goals / Non-Goals

**Goals**

- 每条产生的回收称重数据都提交到 `/api/transports/receive` 并入库。
- 永久拒绝的记录有明确的失败状态，不无限重试。
- 无车牌记录在 Web 上可见、可补选车牌。

**Non-Goals**

- 不在接收时判断数据是否合理；毛重、车牌的修正都留在 Web 收货环节。
- 不上传合同、材料、运单等字段。
- 不给无车牌记录填占位车牌。
- 不改车牌识别与称重周期逻辑。

## Decisions

### 接收不设数据门槛

平台侧没有「异常数据」概念。`Receive` 只保留存不进去才会失败的限制：来源键必填与长度、小数精度、非空车牌的长度。空车牌和负毛重照常入库。Web 收货时修正毛重的 `CorrectGrossWeight` 仍要求非负，因为那是人工纠正，不是接收。

### 车牌按空值提交，不用占位符

占位符会混进接收时按车牌查车辆抄皮重的一步、列表搜索和后续按车牌的统计，还要在各处特判。直接允许 `PlateNumber` 为空：列改可空（一条 migration），列表显示「—」，收货面板补选。

### 永久拒绝标记失败

`SendAsync` 目前把非 2xx 一律当成「下一轮再试」。改为：

- 401：保持待上传，等令牌刷新后重试（沿用现有 401 → `SessionRefreshRequiredEto` 机制）。
- 400（`BusinessException`，响应体带 `code`）：记录状态改为 `SyncStatus.Failed`，不再进入轮询。失败原因只写日志，不存到记录上。接收已不设数据门槛，这条只作为兜底。
- 网络异常、超时、5xx：保持待上传，下一轮重试。

`SyncStatus.Failed` 与列表上的「失败」样式已存在，只是从未写入。

### 状态变更由类型自己完成

- `WeighingRecord` 增加命名方法 `MarkRecycleSyncFailed()`，把状态写入 `ExtraProperties`，不保存失败原因；沿用现有「已同步不回退」的约束。
- 上传请求 DTO 的车牌为可空：`string? PlateNumber`，空白规整为 `null`。DTO 由 `RecycleTransportSubmitDto.FromWeighingRecord(record, sourceClientId)` 生成，不在 Service 里逐字段赋值。
- 服务端 `RecycleTransportRecord.Receive` 的 `plateNumber` 参数改为 `string?`，空白规整为 `null`；去掉对该参数的 `RecycleText.Require`，非空时仍校验长度。
- `MatchesSource` 比较车牌时把 `null` 与空白视为相等。

### 幂等与事后补车牌

客户端只在未同步时重传。Web 端补选车牌发生在记录已同步之后，客户端不会再用旧车牌重传同一条来源记录，所以 `MatchesSource` 不需要为「车牌被改过」放宽。若确实出现，仍按现有 `RECYCLE:IDEMPOTENT_CONFLICT` 拒绝。

## 已定决策

| # | 问题 | 决定 |
|---|------|------|
| 1 | 接收是否区分异常数据 | 不区分。产生称重数据即上传，服务端接收不设数据门槛 |
| 2 | 子仓未提交改动如何处理 | 并入本次提交：与同名分支上的新实现一起提交，后续 squash 进各仓主干 |

## Risks / Trade-offs

- **列改可空需要 migration**：由 `UrbanManagement.Migrator` 执行；138 发布前先跑 migration。
- **失败后不自动恢复**：被 400 拒绝的记录停在失败状态。本单不提供手动重试入口。
- **负毛重进入台账**：列表会出现净重为负的行，由收货时修正毛重；页面已有的「净重为负不计价」规则不变。
- **与在途 change 的关系**：`fix-recycle-client-weighing-upload` 已规定「正常或异常下磅并完成周期都进入待上传」，本单是其补充，不修改该 change 的 delta。
