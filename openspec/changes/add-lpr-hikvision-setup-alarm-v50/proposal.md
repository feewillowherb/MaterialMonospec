## Why

车牌识别设置操作栏已有「测试抓拍 / 编辑 / 删除」，但现场无法从设置页对海康 LPR 做客户端布防（`NET_DVR_SetupAlarmChan_V50`）。当前被动收图依赖 `NET_DVR_StartListen_V30`，部分设备/网络场景需要主动布防通道才能稳定收到车牌报警回调，运维缺少一键验证与启用入口。

## What Changes

- 在「车牌识别设置」DataGrid 操作栏新增「布防」操作（与「测试抓拍」同级）
- 对海康（`DeviceType = Hikvision`）行：登录设备后调用 `NET_DVR_SetupAlarmChan_V50` 建立布防句柄
- 补充 HCNetSDK P/Invoke：`NET_DVR_SETUPALARM_PARAM_V50`、`NET_DVR_SetupAlarmChan_V50`、配套 `NET_DVR_CloseAlarmChan_V30`，以及客户端布防所需的消息回调注册（`NET_DVR_SetDVRMessageCallBack_V31`，若尚未注册）
- 非海康行不展示或禁用「布防」（Vzvision / Huaxiazhixin 不适用）
- **不做**：替换现有 `StartListen_V30` 全局监听主路径；不改 UrbanManagement / BasePlatform；不引入新的第三方包

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- `settings-ui`: 车牌识别设置列表操作栏增加「布防」入口及海康可见性规则
- `license-plate-recognition`: 海康 LPR 支持按配置行执行 `SetupAlarmChan_V50` 客户端布防，并管理布防句柄生命周期

## Impact

- **仓库**：MaterialClient（`SettingsWindow.axaml` / `SettingsWindowViewModel`、`HikvisionSdk`、`HikvisionLprService` / `IHikvisionLprService`）
- **依赖**：现有 HCNetSDK.dll（V6.1.9.48 头文件已声明 V50）；参考 `_tmp/CH-HCNetSDKV6.1.9.48_build20230410_win64`
- **风险**：布防句柄泄漏或重复布防；消息回调与 `StartListen_V30` 并存时需明确注册顺序与共享回调；错误的结构体布局会导致 SDK 失败
- **运维**：设置页可对单台海康设备验证布防是否成功，便于排查「听得到/听不到」报警推送问题
