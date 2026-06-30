## Why

当启动授权过期时，用户通过在线激活成功写入 `LatestJwtToken` 后，当前进程已在 `OnApplicationInitializationAsync` 中因授权失败提前返回，SignalR、轮询上传、后台服务等均未启动。同进程继续显示主界面会导致 UrbanManagement 无法显示客户端在线，且业务服务处于不完整状态。通过在激活成功后重启整个进程，可复用正常的冷启动路径，确保授权门禁与后台服务完整初始化。

## What Changes

- 启动门禁在线激活成功后，不再在同进程内继续显示称重主界面，改为请求进程重启。
- 在 `Program.Main` 退出、单实例 Mutex 释放后拉起新进程（避免与 `MaterialClient_Urban_SingleInstance_Mutex` 冲突）。
- 运行时 F4 设备变更重激活成功后，采用与启动恢复相同的重启策略。
- 激活成功到重启前，执行正常 `Shutdown` 清理（硬件、ABP、SignalR 等），避免资源泄漏。
- 用户取消激活时行为不变：关闭应用，不重启。

## Capabilities

### New Capabilities

- `urban-activation-process-restart`: 定义在线激活成功后的进程重启触发点、Mutex 安全顺序、以及启动/运行时两条恢复路径的统一行为。

### Modified Capabilities

- `urban-license-startup-gate`: 将「在线激活成功后继续启动」改为「在线激活成功后重启进程」；明确同进程不得进入主界面与后台服务。
- `materialclient-urban-activation`: 更新授权 UI 成功后的应用行为描述，从「继续启动」改为「触发进程重启」。

## Impact

- **MaterialClient**（`repos/MaterialClient`）：
  - `Program.cs`：退出后按标志拉起新进程
  - `App.axaml.cs`：启动恢复路径激活成功后请求重启
  - `Events/LicenseDeviceRevokedEventHandler.cs`：F4 重激活成功后请求重启
  - 可选：抽取 `IProcessRestartService` 或静态 `App.RequestRestartOnExit` 标志
- **UrbanManagement**：无变更（客户端重连后由既有 SignalR 连接生命周期逻辑展示在线状态）
- **用户体验**：激活成功后短暂退出并自动重新打开应用，无需用户手动重启
