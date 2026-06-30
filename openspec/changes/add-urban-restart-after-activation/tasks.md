## 1. 进程重启基础设施（MaterialClient.Urban）

- [ ] 1.1 在 `App.cs` 添加 `public static bool RequestRestartOnExit { get; set; }` 与 `RequestProcessRestart(IClassicDesktopStyleApplicationLifetime desktop)` 辅助方法（设置标志 + `Shutdown()`）
- [ ] 1.2 在 `Program.cs` 的 `StartWithClassicDesktopLifetime` 返回后、Mutex `using` 块结束前，当 `App.RequestRestartOnExit` 为 true 时使用 `Environment.ProcessPath` 启动新进程（`UseShellExecute = true`，`WorkingDirectory = AppContext.BaseDirectory`）
- [ ] 1.3 重启启动失败时记录错误日志，不抛未处理异常

## 2. 启动门禁恢复路径

- [ ] 2.1 修改 `App.HandleUnauthorizedStartupAsync`：`RecoverAsync` 返回 true 时调用 `RequestProcessRestart` 并返回 false（不进入主窗口分支）
- [ ] 2.2 确保激活成功重启路径注册 `desktop.Exit += OnApplicationExit`，走正常资源清理
- [ ] 2.3 确认用户取消激活（`RecoverAsync` 返回 false）行为不变：仅 `Shutdown`，不设置重启标志

## 3. F4 运行时设备变更重激活路径

- [ ] 3.1 修改 `LicenseDeviceRevokedEventHandler`：重激活成功后调用 `App.RequestProcessRestart`（UI 线程），替代仅打日志返回
- [ ] 3.2 重激活失败或用户取消时保持现有 `desktop.Shutdown()` 行为

## 4. 验证

- [ ] 4.1 手动验证：过期授权启动 → 在线激活 → 自动重启 → 新进程日志含 `SignalR client connection initiated` 与 `DeviceStatusSignalRClient: Connected successfully`
- [ ] 4.2 手动验证：UrbanManagement 项目管理页对应 `ProId` 显示客户端「在线」
- [ ] 4.3 手动验证：取消激活窗 → 进程退出且无第二实例启动
- [ ] 4.4 手动验证（可选）：F4 `DEVICE_CHANGED` 重激活成功后同样自动重启
