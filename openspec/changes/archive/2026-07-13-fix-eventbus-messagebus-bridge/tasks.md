## 1. 恢复并扩展桥接器（MaterialClient.UI 共享层）

- [x] 1.1 从历史提交 `a6cc5c8^` 恢复桥接逻辑至 `src/MaterialClient.UI/Events/EventBusToMessageBusBridge.cs`（命名空间 `MaterialClient.UI.Events`），含 9 个 `*EventToMessageBusBridge`，按现行 `*EventData`/`*Message` 字段适配；不得仅放在 `MaterialClient` 宿主
- [x] 1.2 在同一文件新增 `UploadCompletedEventToMessageBusBridge`（`UploadCompletedEventData` → `UploadCompletedMessage`）
- [x] 1.3 在同一文件新增 `ServerApprovalSyncedEventToMessageBusBridge`（`ServerApprovalSyncedEventData` → `ServerApprovalSyncedMessage`）
- [x] 1.4 确认全部桥接类为 `ILocalEventHandler<T>, ITransientDependency`，`HandleEventAsync` 仅 `SendMessage`、不切 UI 线程；经 `MaterialClientUiModule` 被主/城管/再生等宿主 ABP 自动注册

## 2. 修复 SettingsSaved 发布路径

- [x] 2.1 `SettingsWindowViewModel` 注入 `ILocalEventBus`（若尚未注入）
- [x] 2.2 保存成功路径改为 `PublishAsync(new SettingsSavedEventData())`，移除单独的 `SendMessage(new SettingsSavedMessage())`
- [x] 2.3 保留 `DetailCloseRequestedMessage` 的 `SendMessage`（VM↔VM，不经桥接）

## 3. 编译与静态核对

- [x] 3.1 `dotnet build MaterialClient.sln -o .build-verify` 通过
- [x] 3.2 全局确认：桥接位于 `MaterialClient.UI/Events/` 且含 11 个桥接类；`MaterialClient` 宿主无重复桥接副本；Common/Urban 发布的需 UI 消费的 `*EventData` 均有对应桥接
- [x] 3.3 确认无「仅 Listen<*Message> + PublishAsync<*EventData>、无桥接」的静默断链残留（含 SettingsSaved）

## 4. 回归验证（对应归档提案 7.x）

- [ ] 4.1 主程序：车牌刷新、称重状态变化、新建记录后列表刷新、详情保存/作废/匹配/完成、手动匹配结果同步
- [ ] 4.2 Urban：上传完成后列表重载；服务端审批同步后列表重载；设置保存后设备状态栏刷新
- [ ] 4.3 设置保存后 Common 侧行为正常（如 `AttendedWeighingService` / `GateIoControlService` 对 `SettingsSavedEventData` 的响应）
- [ ] 4.4 应用关闭：正常关闭与 SDK 回调在途时关闭无死锁/超时
- [ ] 4.5 Recycle（若适用）：车牌/状态等 Common→UI 事件同样可达
