## Why

误录或过磅测试产生的运输行需要在 Web 上作废，且不能动已收货记录。当前运输清单只能收货或查看，没有按业务状态限制的删除入口。

## What Changes

- 运输清单为未收货行提供「删除」操作，点击前弹出确认框。
- 新增 `DELETE /api/transports/{id}`，由 Recycle 运输服务软删除记录（ABP `IsDeleted`），已收货行拒绝删除。
- 列表刷新后软删除行不再出现；客户端同来源重传仍可按既有幂等规则新建。

## Capabilities

### New Capabilities

### Modified Capabilities

- `recycle-web-persistence-api`：运输清单删除与未收货约束。

## Impact

- `UrbanManagement.Core`：`IRecycleTransportAppService`、运输服务删除逻辑。
- `UrbanManagement.Recycle`：HTTP 端点、`Transports.vue`。
- 不涉及市平台上报、不硬删数据库行。