## Why

回收称重列表复用城管行模型，把上传时间固定为空、同步状态固定为待上传，并用异常标记冒充状态。回收称重本身已有车牌、重量、收发、抓拍时间和平台接收结果，列表应直接展示这些事实。

## What Changes

- 回收称重列表使用本机自己的查询和行类型，不再使用城管列表 DTO、`SyncStatus`、`UrbanInOutType`、`IsAnomaly` 或 `AnomalyReason`。
- 行上的车牌、重量、收发、抓拍时间、车牌颜色和车型取自称重记录。
- 上传时间取平台接收被确认的时刻；确认前或历史记录没有该时刻时显示「—」。
- 状态列显示平台接收状态：未上传、待上传、已上传。
- 异常、卡口、成品页签仍不返回记录。正常和全部列出回收称重。

## Capabilities

### New Capabilities

- `recycle-weighing-list`: 回收称重主界面列表的字段来源和展示。

### Modified Capabilities

## Impact

MaterialClient.Recycle 的列表服务、主窗口绑定，以及称重记录上的平台接收确认时间。不改城管列表，不改 Recycle Web。
