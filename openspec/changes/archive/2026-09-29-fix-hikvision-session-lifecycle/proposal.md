## Why

Urban 现场出现大量 PC→相机 `:8000` TCP RST，且 `IsOnline` 以 Login/Logout 测活、LPR 与监控分持会话、soft-reset Cleanup 后不重建 Listen，导致会话抖动与 Listen「假存活」。需要在不引入布防的前提下，修好登录与会话持有，提升稳定性与可观测性。

## What Changes

- 将海康设备会话改为**长持有**：启动时 Login 并缓存；抓拍复用缓存；停止时成对 Logout
- `IsOnline` **禁止** Login→立刻 Logout；改为对已有 `lUserID` 调用 `NET_DVR_RemoteControl` + `NET_DVR_CHECK_USER_STATUS`（`20005`）轻量探活（默认节流 30s），失败再 Invalidate 后单次 Login
- soft-reset（`Cleanup`）后：**清空 LPR 会话缓存**并 **重建 `StartListen`**（与监控侧同感知）
- `ContinuousShoot` 成功后若短窗口无报警回调，打 **Warning**（可观测静默失败）
- 监控抓拍与 LPR **共享同一设备会话**（同一 `Ip:Port:User` 一个 `userId`），避免重复登录

**Out of scope（本 change 明确排除）：**

- 一切布防相关：`SetupAlarmChan` / `CloseAlarmChan` / `SetDVRMessageCallBack_V31` / 自动布防（调研 P3）
- 统一合并两套 P/Invoke 类型为单一文件（可后续 change；本 change 只要求会话语义共享）
- 车牌业务过滤 / 设置页「无牌有图」展示（已有独立分支时可另合）

## Capabilities

### New Capabilities

- `hikvision-session-lifecycle`: 海康 SDK 登录会话的持有、探活、失效清理、soft-reset 后重建 Listen，以及抓拍后无回调告警

### Modified Capabilities

- （无）本 change 不修改既有 license-plate-recognition 的识别/事件语义；会话生命周期以新 capability 约束

## Impact

- **仓库**：MaterialClient（`HikvisionLprService`、`HikvisionService`、`DeviceManagerService`、在线状态服务）
- **宿主**：MaterialClient.Urban（及共用 Common 的其它桌面宿主）
- **依赖**：HCNetSDK（探活 API 以 `HCNetSDK.h` 为准）；调研输入 `docs/2026-09-16-mc-hikvision-login-session-issues/`
- **风险**：会话共享后需仔细处理 soft-reset 与 Stop 顺序，避免一边 Logout 另一边仍持旧 Id
