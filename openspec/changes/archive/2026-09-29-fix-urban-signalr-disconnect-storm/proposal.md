## Why

生产日志（`log-20260911`）显示 localhost / Blazor 卡顿约 1 分钟：`DeviceStatusHub` 在 `ClientTimeoutInterval` 下成批断连，断连写 SQLite 大量 `TaskCanceledException`。根因是 **SignalR 热路径同步打 EF/SQLite**；项目管理页再连 `/hubs/devicestatus` 加重负载。产品接受 **连接态易失**：以 Redis 为主存当前在线/设备态，热路径 **不再写 SQLite**；UM/Redis 重启后视为全部离线直至客户端重连。

## What Changes

- **连接/设备当前态改为 Redis 主存**：`OnConnected` / `OnDisconnected` / `UploadStatus` 热路径只写 Redis（带 TTL），**禁止** EF `ClientOnlineStatus` / `ClientDeviceOnlineStatus` upsert
- 项目管理徽章与设备弹窗查询以 **Redis 为准**；缺 key / Redis 清空 = 离线或未注册（**接受连接丢失**，不回源 SQLite）
- 引入本机 Redis（[tporadowski/redis](https://github.com/tporadowski/redis)）：默认 **`127.0.0.1:6379`**，服务端 **`maxmemory 100mb`** + `allkeys-lru`；ABP `IDistributedCache` 后端接 Redis；**不做** SignalR Redis 背板
- 为宿主 SignalR 增加可配置 `ClientTimeoutInterval` / `KeepAliveInterval`
- **移除** `ProjectManagement.razor` 对 `/hubs/devicestatus` 的 `HubConnection`、订阅与 **30s 轮询**；仅 HTTP + 手动刷新
- **保留** `MapHub<DeviceStatusHub>` 与 `MapBlazorHub`；MaterialClient Hub 协议不变
- **不**借机大改 GovSync / WAL；表结构可保留但热路径与实时查询不再依赖

## Capabilities

### New Capabilities

- `urban-signalr-hub-resilience`: Hub 热路径不打 EF；超时可配置；Web 不订阅 DeviceStatus Hub
- `urban-redis-distributed-cache`: Redis 作为连接/设备当前态主存与 ABP 分布式缓存后端（Windows 本机 6379 / 100MB）

### Modified Capabilities

- `device-online-status-persistence`: 实时连接与设备当前态改为 Redis 主存；接受进程/Redis 重启后连接丢失；查询不再以 SQLite 为权威
- `blazor-project-management`: 去掉实时 SignalR 与轮询；手动刷新（数据来自 Redis 支持的 AppService）
- `project-client-merge`: 去掉 SignalR 订阅与 30s fallback polling

## Impact

- **子仓库**：`repos/UrbanManagement`（Hub、`DeviceStatusService`、查询路径、Redis 模块、`ProjectManagement.razor`、`appsettings`）
- **运维**：必须运行 tporadowski/redis（或兼容实例）；未装 Redis 时缓存/在线态不可用且须可观测失败
- **语义**：重启或 Redis 清空后管理页显示离线/未注册，直至桌面端重连——**产品已接受**
- **桌面端**：Hub 协议不变
- **分支**：Mode A — `fix-urban-signalr-disconnect-storm`
