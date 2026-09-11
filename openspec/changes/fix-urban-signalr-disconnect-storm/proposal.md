## Why

生产日志（`log-20260911`）显示 localhost / Blazor 卡顿约 1 分钟：`DeviceStatusHub` 在 `ClientTimeoutInterval` 下成批断连，断连写 SQLite 大量 `TaskCanceledException`。同时项目管理页浏览器侧再连 `/hubs/devicestatus` 做实时刷新，加重 Hub 负载且非业务必需。Web 不需要 DeviceStatus SignalR；状态由用户手动刷新即可。

## What Changes

- 优化 `DeviceStatusHub` 断连处理：离线持久化不得依赖已取消的连接 `CancellationToken`；独立作用域 / 非 abort CT；取消类失败降噪
- 为宿主 SignalR（桌面端 Hub + Blazor Server 电路）增加可配置 `ClientTimeoutInterval` / `KeepAliveInterval`
- **移除** `ProjectManagement.razor` 对 `/hubs/devicestatus` 的 `HubConnection`、`SubscribeClientConnection`、以及 **30s 兜底轮询**；客户端连接状态仅在进入页面 / 用户手动刷新时通过 `IDeviceStatusAppService` HTTP 加载
- **保留** `MapHub<DeviceStatusHub>` 供 MaterialClient；**保留** `MapBlazorHub`（Blazor Server 必需）
- 将 ABP `IDistributedCache`（设备状态 / 连接注册等已有缓存）从进程内内存改为 **Redis** 后端：现场 Windows 使用 [tporadowski/redis](https://github.com/tporadowski/redis)，**默认端口 6379**，服务端 **`maxmemory 100mb`**
- **不**借机大改 GovSync worker / WAL；**不**引入 SignalR Redis 背板（多实例 Hub scale-out）

## Capabilities

### New Capabilities

- `urban-signalr-hub-resilience`: DeviceStatusHub 断连韧性、超时可配置；Web 管理页不订阅 DeviceStatus Hub
- `urban-redis-distributed-cache`: UrbanManagement 分布式缓存使用 Redis；Windows 本机默认 `127.0.0.1:6379`、内存上限 100MB

### Modified Capabilities

- `device-online-status-persistence`: 断连 upsert 在 Hub 连接已中止时仍须尽力完成
- `blazor-project-management`: 去掉实时 SignalR 与轮询；手动刷新
- `project-client-merge`: 去掉 SignalR 订阅与 30s fallback polling 要求

## Impact

- **子仓库**：`repos/UrbanManagement`（Hub、SignalROptions、AppModule、`ProjectManagement.razor`、`appsettings`、ABP Redis 缓存包与模块）
- **运维**：Windows 主机须安装并运行 tporadowski/redis（或兼容 Redis），配置 `maxmemory 100mb`；应用连 `127.0.0.1:6379`
- **桌面端**：MaterialClient Hub 协议不变
- **Web UX**：项目管理页客户端状态不再实时推送；用户自行刷新（或重新进入页面）
- **分支**：Mode A — `fix-urban-signalr-disconnect-storm`
