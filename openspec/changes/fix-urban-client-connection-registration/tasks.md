## 1. MaterialClient：连接恢复登记顺序

- [x] 1.1 修改 `DeviceStatusSignalRClient.OnConnectionRestoredAsync`：`FlushMessageQueue` → `SyncProjectLicenseFromServerAsync` → `Publish(SignalRConnectionRestoredEventData)`
- [x] 1.2 在 `OnConnectionRestoredAsync` 末尾注入 `ISharedDeviceStatusTrackerRegistry` 并调用 `RepublishActiveStatuses()` 兜底
- [x] 1.3 确认 `SignalRConnectionRestoredHandler` 行为与新区顺序一致，无需额外改动或补充注释

## 2. UrbanManagement：项目管理页 SignalR 订阅

- [x] 2.1 在 `ProjectManagement.razor` 的 `InitializeSignalRAsync` 中，`StartAsync` 成功后调用 `InvokeAsync("SubscribeClientConnection")`
- [x] 2.2 在 `Reconnected` 回调中重新调用 `SubscribeClientConnection`
- [x] 2.3 `SubscribeClientConnection` 失败时记录日志，不阻塞页面其余功能

## 3. 验证

- [ ] 3.1 手动验证：启动 MaterialClient（含激活/重启路径）后，UrbanManagement 日志出现 `Cached client connected. ProId=...`
- [ ] 3.2 手动验证：项目管理页已打开时，客户端连接后状态由「未注册」变为「在线」，无需 F5
- [ ] 3.3 手动验证：F5 刷新后状态与实时一致；客户端断开后变为「离线」
