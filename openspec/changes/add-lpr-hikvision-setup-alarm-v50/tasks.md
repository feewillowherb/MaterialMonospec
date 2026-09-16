## 1. HCNetSDK P/Invoke

- [x] 1.1 在 `HikvisionSdk` 增加 `NET_DVR_SETUPALARM_PARAM_V50`（布局对齐 HCNetSDK.h V6.1.9.48，含 `byRes4[128]`）
- [x] 1.2 声明 `NET_DVR_SetupAlarmChan_V50`、`NET_DVR_CloseAlarmChan_V30`、`NET_DVR_SetDVRMessageCallBack_V31`（及 V31 回调委托，若与现有 `MSGCallBack` 签名不同则单独定义）
- [x] 1.3 扩展 struct layout 测试，锁定 `NET_DVR_SETUPALARM_PARAM_V50` 的 `Marshal.SizeOf`

## 2. Hikvision LPR 布防服务

- [x] 2.1 新增命名 `record` 结果类型（如 `HikvisionAlarmArmResult`）；在 `IHikvisionLprService` / `HikvisionLprService` 实现 `SetupAlarmChanAsync(LicensePlateRecognitionConfig)`
- [x] 2.2 布防流程：EnsureInitialized → 登录/复用 userId → 确保 `SetDVRMessageCallBack_V31`（GCHandle 钉住，复用既有 `MessageCallback`）→ 默认 V50 参数 → `SetupAlarmChan_V50`；失败读 `GetLastError`
- [x] 2.3 按设备键缓存 alarmHandle；重复布防先 `CloseAlarmChan_V30`；`StopAsync` / `DisposeAsync` 关闭全部句柄

## 3. 设置页 UI

- [x] 3.1 `SettingsWindow.axaml` LPR 操作栏增加「布防」按钮；仅 `DeviceType = Hikvision` 可见（或等效门控）
- [x] 3.2 `SettingsWindowViewModel` 增加布防 `ReactiveCommand`：海康行调用服务，日志记录成功/失败；可选更新行短状态文案
- [x] 3.3 调整操作列宽度以容纳新按钮

## 4. 验证

- [x] 4.1 `dotnet build` MaterialClient（必要时 `-o .build-verify`）通过
- [ ] 4.2 手动：海康行点「布防」成功；非海康行无按钮；重复点击不泄漏句柄；关闭应用无未释放句柄告警
