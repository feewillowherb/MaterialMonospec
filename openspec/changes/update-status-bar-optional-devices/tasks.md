## 1. 配置与持久化

- [ ] 1.1 在 `SystemSettings` / `SettingsEntity` 增加 `DocumentCameraEnabled`（默认 `false`），经 `ISettingsService` 读写
- [ ] 1.2 确认 `IsPrinterEnabled`、`SoundDeviceEnabled` 字段名与设置 VM 一致，供状态栏 catalog 读取

## 2. 设置窗口 — 高拍仪分区

- [ ] 2.1 在 `MaterialClient.UI` 的 `SettingsWindow.axaml` 增加「高拍仪」导航项与内容区（启用 Toggle + 连接/测试控件）
- [ ] 2.2 在 `SettingsWindowViewModel` 绑定 `DocumentCameraEnabled` 及现有 USB/文档摄像头配置字段
- [ ] 2.3 未启用时禁用测试与连接控件；保存时写入完整 `SettingsEntity`

## 3. 设备启动 — 可选启动

- [ ] 3.1 设备管理器 / 启动管线：`DocumentCameraEnabled == false` 时不启动高拍仪服务
- [ ] 3.2 打印机、音响保持既有启用判断，未启用时不启动（若当前仍会启动则修正）

## 4. 设备状态栏 — 动态可见性

- [ ] 4.1 实现或扩展动态 catalog：默认仅地磅、海康摄像头、车牌识别
- [ ] 4.2 `DocumentCameraEnabled`、`IsPrinterEnabled`、`SoundDeviceEnabled` 为 true 时加入对应 `DeviceStatusItem` 并订阅事件
- [ ] 4.3 未启用设备不得出现在状态栏（无离线占位）
- [ ] 4.4 设置保存后刷新 catalog（`SettingsSavedMessage` 或等价机制）

## 5. 应用验证

- [ ] 5.1 MaterialClient 主应用：默认仅三项；启用打印机/高拍仪/音响后保存，状态栏出现对应项；禁用后消失
- [ ] 5.2 MaterialClient.Urban：默认三项；启用可选设备后行为与主应用 catalog 一致
- [ ] 5.3 `dotnet build` MaterialClient 解决方案通过

## 6. OpenSpec

- [ ] 6.1 运行 `openspec validate update-status-bar-optional-devices --strict` 并通过
