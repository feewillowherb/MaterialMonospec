## Context

`RecycleTransportRecord` 已是 `FullAuditedAggregateRoot<Guid>`，仓储 `DeleteAsync` 即软删除。车辆页已有 `DELETE /api/vehicles/{id}` 与 `ElMessageBox.confirm` 模式。运输状态：「已收货」当且仅当 `ReceivingTime` 有值。

## Goals / Non-Goals

**Goals**

- 未收货（含「待补皮重」「待收货」）行可软删除。
- 已收货行删除请求返回业务错误，页面不展示删除按钮。
- 删除前必须确认。

**Non-Goals**

- 不批量删除、不清理附件文件、不改市平台同步状态逻辑。
- 不恢复已删除行的 UI。

## Decisions

### 删除判定

服务以 `ReceivingTime is null` 为准，与列表状态「已收货」一致。跨项目仍用 `ProId` 校验。

### API

`DELETE /api/transports/{id}`，成功 `204 NoContent`；已收货 `RECYCLE:TRANSPORT_RECEIVED`；不存在 `RECYCLE:NOT_FOUND`。

### 前端

操作列：已收货仅「查看」，否则「收货」+「删除」。删除文案含车牌，确认后 `DELETE` 并 `load()`。错误从响应体展示。

## Risks / Trade-offs

软删除后 `ReceiveAsync` 的 `IgnoreQueryFilters` 幂等路径仍可能命中已删行；若需同来源再入库，可后续单独 change 在接收时处理已删行。本单不扩展接收逻辑。