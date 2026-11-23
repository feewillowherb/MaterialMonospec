## 1. 列表

- [x] 1.1 在称重记录上保存平台接收确认时间，上传成功时写入且不覆盖已有时刻。
- [x] 1.2 用回收列表行和查询替换城管列表类型。行从称重记录投影，不包含异常字段。
- [x] 1.3 主窗口绑定回收列表行。收发、上传时间和状态按记录显示。异常、卡口、成品页签保持为空。
- [x] 1.4 列表上传状态使用 `SyncStatus` 和 `UploadTime`。不引入 `IsAnomaly` 或城管进出类型。
- [x] 1.5 回收状态命名改为 `RecycleSyncStatus` 的 `Pending` / `Synced`，确认时间改为 `RecycleSyncedAt`。继续读取旧的 `Accepted`。
- [x] 1.6 客户端提交服务命名对齐城管：`IRecycleServerUploadService.SubmitRecordAsync` 与 `RecycleTransportSubmitDto`。服务端接收入参命名为 `RecycleTransportReceiveInputDto`。

## 2. 验证

- [x] 2.1 编译 `MaterialClient.Recycle`。不创建分支，不停止正在运行的客户端。
