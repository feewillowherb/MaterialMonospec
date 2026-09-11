## Why

现场日志显示海康主码流抓拍可连续多车全部失败（`decoder init timeout` / PlayM4 32），称重流程仍继续但无照片；进程内每次抓拍虽会新建 `PlayM4Decoder`，但 `NET_DVR_Init` 不会因失败复位，只能靠重启应用恢复。需要运行时自愈，避免依赖人工重启。

## What Changes

- 在连续批量抓拍失败（或连续 decoder init timeout）达到阈值时，执行 **HCNetSDK 软复位**（登出缓存会话 → `NET_DVR_Cleanup` → `NET_DVR_Init`），并在同一轮抓拍中重试一次
- 软复位加互斥与冷却，避免称重高峰反复 Cleanup
- 主码流 `decoder init timeout` 必须仍走既有设备侧 JPEG 降级；超时日志区分「未收到 SYSHEAD」与「OpenStream/Play 失败」，避免仅报误导性的 PlayM4 32
- `WaitForPlaying` 超时可配置（默认保持 5000ms），便于弱网现场调参
- **不做**：强制改现场 `CaptureStreamType`；不引入无图补拍 UI；不改 UrbanManagement

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- `hikvision-session-lifecycle`: 增加连续失败触发的 SDK 软复位（Cleanup + Init）与冷却/互斥要求
- `weighing-device-capture`: 批量抓拍在软复位后同一轮重试一次；全失败仍优雅返回空列表
- `mainstream-capture-fallback`: 明确 decoder init timeout 触发降级；超时诊断日志要求

## Impact

- **仓库**：MaterialClient（`HikvisionService`、`PlayM4Decoder` / 端口池、`WeighingCaptureService`；Attended / Urban 共用抓拍路径）
- **依赖**：现有 HCNetSDK / PlayM4 P/Invoke；不新增第三方包
- **风险**：软复位短暂中断其他海康登录/预览调用方，需冷却与锁；错误实现可能导致更长卡顿
- **运维**：减少「无图必须重启客户端」；日志可观测复位与降级
