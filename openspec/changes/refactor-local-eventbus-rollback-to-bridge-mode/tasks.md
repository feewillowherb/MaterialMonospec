# Tasks

## 1. 恢复桥接器与 Message 载荷类型

- [ ] 1.1 从历史提交 `a6cc5c8^` 恢复 `src/MaterialClient/Events/EventBusToMessageBusBridge.cs`，含 9 个 `*EventToMessageBusBridge`（`ILocalEventHandler<TEventData>, ITransientDependency`，`[AutoConstructor]`），按现行命名空间与 `using` 适配
- [ ] 1.2 恢复 8 个 `*Message` 类至 `src/MaterialClient.Common/Events/`：`StatusChangedMessage`、`PlateNumberChangedMessage`、`DeliveryTypeChangedMessage`、`WeighingRecordCreatedMessage`、`UpdatePlateNumberMessage`、`MatchSucceededMessage`、`SettingsSavedMessage`、`GhostGateSessionResetMessage`（字段与现行 `*EventData` 一一对应）
- [ ] 1.3 确认 `LicensePlateRecognizedMessage` 已存在且字段与 `LicensePlateRecognizedEventData` 一致，补齐缺失字段
- [ ] 1.4 验证桥接器由 ABP 自动注册（`ITransientDependency` + `ILocalEventHandler<T>`），无需显式 `Register`/`Subscribe`

## 2. 重写 ViewModel / View 事件消费端

- [ ] 2.1 `AttendedWeighingViewModel`：将 11 处 `_localEventBus.Subscribe<*EventData>(lambda)` 改为 `MessageBus.Current.Listen<*Message>().ObserveOn(RxApp.MainThreadScheduler).Subscribe(...)`，订阅收集进 `CompositeDisposable`（`_disposables`）
- [ ] 2.2 `AttendedWeighingViewModel`：删除各回调内 `Dispatcher.UIThread.Post(...)` 包装，UI/列表更新并入 `ObserveOn` 管线
- [ ] 2.3 `UrbanAttendedWeighingViewModel`：订阅（`PlateNumberChanged`、`SettingsSaved` 等）改回 `Listen<*Message>().ObserveOn().Subscribe()`，收集进 `_subscriptions`
- [ ] 2.4 `UrbanAttendedWeighingViewModel`：`ReloadRecordsAsync` 的 `TotalCount/TotalPages/Clear/Add` 收敛进 `ObserveOn(RxApp.MainThreadScheduler)` 管线
- [ ] 2.5 `SettingsWindowViewModel`：`Subscribe<LicensePlateRecognizedEventData>` → `Listen<LicensePlateRecognizedMessage>().ObserveOn().Subscribe()`
- [ ] 2.6 `SettingsWindow.axaml.cs`：`Subscribe<DetailCloseRequestedEventData>` → `Listen<DetailCloseRequestedMessage>().ObserveOn().Subscribe()`

## 3. 回退 ViewModel↔ViewModel 事件发布端

- [ ] 3.1 `AttendedWeighingDetailViewModelBase`：`PublishAsync(DetailOperationCompletedEventData)` → `MessageBus.Current.SendMessage(DetailOperationCompletedMessage)`
- [ ] 3.2 `AttendedWeighingDetailViewModelBase`：`PublishAsync(DetailCloseRequestedEventData)` → `SendMessage(DetailCloseRequestedMessage)`
- [ ] 3.3 `ManualMatchEditWindowViewModel`：`PublishAsync(ManualMatchSaveCompletedEventData)` → `SendMessage(ManualMatchSaveCompletedMessage)`
- [ ] 3.4 补齐缺失的 VM↔VM `*Message` 类型（`DetailOperationCompletedMessage`、`DetailCloseRequestedMessage`、`ManualMatchSaveCompletedMessage`）至 `MaterialClient.Common/Events/`，字段对齐对应 `*EventData`

## 4. 移除手动并发补丁

- [ ] 4.1 移除 `UrbanAttendedWeighingViewModel._reloadGate`（`SemaphoreSlim`）及其 `WaitAsync/Release/Dispose`（即 `fc8a4f9` 引入的手写锁）
- [ ] 4.2 全局排查 ViewModel 内为事件回写而新增的 `SemaphoreSlim` / `Dispatcher.UIThread.InvokeAsync`，能由 `ObserveOn` 串行化替代者一律移除
- [ ] 4.3 确认 `Dispatcher.UIThread` 仅保留在真正需要主线程同步的非事件路径（窗口显隐、对话框等），事件回写路径不再依赖

## 5. 保留范围核对（不改）

- [ ] 5.1 核对 5 个纯基础设施 Handler 保持 `ILocalEventHandler<T>` 不变：`DeviceStatusEventHandler`、`TryMatchEventHandler`、`SessionRefreshRequiredEventHandler`、`SignalRConnectionRestoredHandler`、`UrbanWeighingUploadRequestedEventHandler`
- [ ] 5.2 核对 2 个 Urban 生命周期 Handler 保持不变：`LicenseExpiredEventHandler`、`LicenseDeviceRevokedEventHandler`（应用生命周期，非列表竞态）
- [ ] 5.3 核对 Common 服务发布端继续 `_localEventBus.PublishAsync(*EventData)`，SDK 回调保持 fire-and-forget

## 6. 编译验证

- [ ] 6.1 `dotnet build MaterialClient.sln -o .build-verify`（避开文件锁的独立输出目录），确认全解决方案编译通过
- [ ] 6.2 全局搜索确认运行时代码（测试桩除外）无残留 `_localEventBus.Subscribe` 用于 UI 事件消费；桥接器 `SendMessage` 与 ViewModel `Listen` 配对完整

## 7. 回归验证

- [ ] 7.1 主程序：车牌刷新、称重状态变化、详情保存/作废/匹配/完成、手动匹配结果同步
- [ ] 7.2 Urban：`/api/lpr/test-plate` 注入后 UI 车牌实时更新；记录重载（`ReloadRecordsAsync`）无重复行/数量异常
- [ ] 7.3 高并发场景：连续多线程触发同一事件，`ObservableCollection` 无竞态（无重复、无内核崩溃）
- [ ] 7.4 应用关闭：正常关闭与 SDK 回调在途时关闭均无死锁/超时
