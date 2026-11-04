## Why

大量无 SignalR 的旧客户端仅靠 Legacy `/Api/Post` → `ReceiveAsync` Touch 写 Redis 在线态，但 live TTL 与 SignalR 共用约 120 秒，过磅间隔往往更长，管理端几乎一直显示离线。需要为 Legacy 实例单独拉长业务活跃窗口至 0.5 小时，使成功过磅后徽章可保持在线一段时间。

## What Changes

- Legacy 在线实例（`ClientId` 以 `legacy:` 为前缀）在 Touch / 建 live 键时使用 **0.5 小时（30 分钟）** live TTL，不再使用 SignalR 的短 live TTL。
- SignalR / 非 `legacy:` 前缀的 ClientId 保持现有 live TTL（`ClientTimeoutIntervalSeconds × 2`）不变。
- 不改变 Legacy `ClientId = legacy:{AccessCode}` 约定，不改变 EF Redis-miss 强制离线兜底，不新增 Hub 方法，不要求旧客户端升级。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `device-online-status-persistence`: Legacy 过磅 Touch 的 live Redis TTL 固定为 0.5h；与 SignalR live TTL 分离。

## Impact

- **UrbanManagement**：`DeviceStatusService`（及可选配置项）在为 `legacy:` ClientId 写 live `ClientConnection` 时应用 30 分钟 TTL；`ReceiveAsync` / Legacy Post 路径行为不变，仅续期时长变化。
- **管理端徽章**：成功 Legacy Post 后约 30 分钟内该项目可显示在线；超时无再 Post 则自然离线。
- **MaterialClient / 旧客户端**：无强制变更。
- **非目标**：Hub 映射定时续期、现代工控 SignalR 心跳、全局加长 SignalR TTL。
