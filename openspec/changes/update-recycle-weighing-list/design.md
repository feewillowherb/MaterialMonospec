## Context

回收主界面列表通过城管 `UrbanWeighingListItemDto` 组装行。调用处把 `uploadTime` 固定为 `null`，把 `syncStatus` 固定为 `Pending`，把 `isAnomaly` 固定为 false。平台接收结果写在称重记录的 `RecycleWebReceiveState`，确认成功时没有保存时间。

## Goals / Non-Goals

**Goals**

- 列表行由回收称重记录投影，字段来自称重记录和平台接收状态。
- 确认上传成功时记下确认时间，列表显示该时间。
- 状态列表示平台接收，不表示异常。

**Non-Goals**

- 不补传尚未标记待上传的历史称重。
- 不使用 `IsAnomaly`、`AnomalyReason`。
- 不在上报请求中选择或附带照片。
- 不创建实现分支。

## Decisions

- 行类型和查询类型放在 `MaterialClient.Recycle`。投影用 `RecycleWeighingListRow.FromWeighingRecord`。
- 收发取 `WeighingRecord.DeliveryType`：收料显示「收」，发料显示「发」，空值显示「—」。列表列名使用「收发」。
- 抓拍时间取 `AddDate`。车牌、重量、车牌颜色、车型取记录上的对应字段。重量沿用吨。
- 平台接收确认时间存在 `ExtraProperties` 的 `RecycleWebReceiveAcceptedAt`。`MarkRecycleWebReceiveAccepted` 接收确认时刻，已有时刻时不覆盖。
- 列表上的上传状态使用 `SyncStatus`。回收称重把同一套名字写在记录的 `RecycleSyncStatus`：`Pending`、`Synced`。确认时间键为 `RecycleSyncedAt`。不写入 `UrbanWeighingExtension`。已有的 `RecycleWebReceiveState` 值 `Accepted` 仍按 `Synced` 读取。显示文字用枚举说明：null 为「—」，待上传，已同步。
- 客户端提交服务沿用城管命名：`IRecycleServerUploadService.SubmitRecordAsync`，提交体为 `RecycleTransportSubmitDto`。服务端接收入参为 `RecycleTransportReceiveInputDto`，方法仍是 `ReceiveAsync`。
- 车牌颜色和车型属性名与城管列表相同：`PlateColor`、`VehicleType`。收发仍取 `DeliveryType`，不改成城管进出类型。
- 异常、卡口、成品页签返回空列表。正常和全部返回全部回收称重。
- 继续使用 ReactiveUI 和现有 `ListBox` 编译绑定，只更换行类型。

## Risks / Trade-offs

- 本变更之前已确认的记录没有确认时间，上传时间仍为「—」，直到新的确认写下时刻。
