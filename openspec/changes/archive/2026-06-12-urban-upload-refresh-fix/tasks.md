## 1. 定义事件类

- [x] 1.1 在 `MaterialClient.Common/Events/` 中创建 `UploadCompletedEventData` 类，继承 `EventData`，包含 `WeighingRecordId` 属性

## 2. 后台 Worker 发布事件

- [x] 2.1 在 `PollingBackgroundService` 构造函数中注入 `ILocalEventBus`
- [x] 2.2 在 `UploadPendingRecordsAsync` 循环中，`SubmitRecordAsync` 成功调用后发布 `UploadCompletedEventData`

## 3. ViewModel 订阅事件

- [x] 3.1 在 `UrbanAttendedWeighingViewModel.Initialize()` 中添加 `UploadCompletedEventData` 订阅，调用 `ReloadRecordsAsync()`，包含 try/catch 错误处理
