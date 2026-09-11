## Context

- 现场 `Logs/log-20260911.txt`：外呼亚秒级；`DeviceStatusHub` `ClientTimeoutInterval` 断连约 481 次；断连持久化 `TaskCanceledException` 约 265 次；Hub 会话 p50≈86s。
- 根因链：断连路径 EF 使用已取消连接 CT + Hub 负载；项目管理页浏览器再连 `/hubs/devicestatus` 做实时刷新（非必需）。
- 产品决定：**Web 不订阅 DeviceStatus SignalR**；**不要轮询**；状态靠用户手动刷新 / 重新进入页面。

## Goals / Non-Goals

**Goals:**

- 断连离线落库在 connection abort 后仍可完成（独立 scope + 非 ConnectionAborted CT）。
- Hub `OnDisconnectedAsync` 尽快返回；取消类失败降噪；可配置 KeepAlive / ClientTimeout。
- 移除 `ProjectManagement.razor` 的 DeviceStatus `HubConnection`、订阅与 30s 兜底轮询；仅 HTTP 加载 + 手动刷新。
- 保留桌面端 `MapHub<DeviceStatusHub>` 与 Blazor Server `MapBlazorHub`。
- 将现有 ABP `IDistributedCache` 后端接到本机 Redis（进程重启后缓存仍可跨应用池回收存活；减轻与 SQLite 争用时的纯内存丢失）。

**Non-Goals:**

- 删除 `DeviceStatusHub` 或改 MaterialClient 协议。
- 用定时轮询替代实时推送。
- GovSync UoW/WAL。
- **SignalR Redis 背板**（`AddStackExchangeRedis` 做 Hub scale-out）——本 change 只换分布式缓存存储，不做多节点 Hub。
- 去掉 Blazor Server 电路 SignalR（`/_blazor`）。
- 改写 `DeviceStatusService` 缓存键语义 / TTL 业务规则（沿用现有 `AbpDistributedCacheOptions` 与 `UM:` 前缀）。

## Decisions

### D1: 断连持久化使用独立 DI 作用域 + 非 abort CancellationToken

**选择**：`OnDisconnectedAsync` 经 `IServiceScopeFactory.CreateScope()` 解析服务；upsert 使用独立 CT（短超时或 `None`），禁止把 `Context.ConnectionAborted` 传到 EF。

**理由**：日志中 `SaveChangesAsync` 在断连瞬间被 `TaskCanceledException` 取消。

### D2: Hub 路径「尽力而为」，失败分级日志

- 预期取消 / 短超时 → Warning/Debug，不刷 Error 风暴。
- 其他异常仍 Error。
- 广播 `ClientConnectionUpdate` 仍可供**非 Web**订阅者（若有）；Web 不再加入 `client_connection` 组。

### D3: 可配置 SignalR 心跳与客户端超时

扩展 `SignalROptions`：`KeepAliveIntervalSeconds` 默认 15，`ClientTimeoutIntervalSeconds` 默认 60（须大于 KeepAlive）。应用到 `AddSignalR`；Blazor hub options 对齐超时（电路稳定性，与 DeviceStatus 浏览器客户端无关）。

### D4: 不在本 change 做断连写库队列化

同步 await + 独立 CT/scope 即可。

### D5: 移除 Web DeviceStatus SignalR，不引入轮询

**选择**：删除 `ProjectManagement.razor` 中 `HubConnection` / `InitializeSignalRAsync` / `SubscribeClientConnectionAsync` / `StartFallbackPolling` 及相关字段与 Dispose 清理；列表与客户端状态仅在 `OnInitialized`（及现有用户触发的刷新操作，如搜索/翻页/显式刷新按钮若已有）经 `IDeviceStatusAppService` 拉取。

**若无显式「刷新」按钮**：依赖用户切换筛选、翻页、重新进入页面，或补一个轻量「刷新」按钮（推荐，避免只能 F5）。**禁止**后台 `Task.Delay` 轮询。

**理由**：用户明确不要轮询；实时推送非 Web 必需；减少浏览器 Hub 连接。

**备选否决**：30s 轮询（用户拒绝）；保留 HubConnection 只去订阅（仍占连接）。

### D6: 保留服务端 Hub 与 Blazor 电路

`endpoints.MapHub<DeviceStatusHub>("/hubs/devicestatus")` 与 `MapBlazorHub` 不变。`SubscribeClientConnection` Hub API 可保留供将来非 Web 用途，本 change 不要求删除服务端方法。

### D7: ABP 分布式缓存使用本机 Redis（非 SignalR 背板）

**选择**：引入 `Volo.Abp.Caching.StackExchangeRedis`（与现网 ABP 10.0.1 对齐），Core/App 模块 `DependsOn` `AbpCachingStackExchangeRedisModule`；连接串默认 `127.0.0.1:6379`。保留现有 `AbpDistributedCacheOptions.KeyPrefix = "UM:"` 与各 CacheItem TTL。

**现场 Redis**：Windows 安装 [tporadowski/redis](https://github.com/tporadowski/redis)（Redis for Windows），监听**默认端口 6379**。在 `redis.windows.conf`（或等价配置）设置：

```text
maxmemory 100mb
maxmemory-policy allkeys-lru
```

（100MB 为**服务端**上限；应用侧不另造第二套内存配额。`allkeys-lru` 在触顶时淘汰，避免 `maxmemory` 写满后拒绝写入拖垮状态上报。）

**配置草图**（`appsettings.json`）：

```json
"Redis": {
  "Configuration": "127.0.0.1:6379"
}
```

**理由**：`DeviceStatusService` 已依赖 `IDistributedCache<DeviceStatusCacheItem|ClientConnectionCacheItem|ClientRegistryCacheItem>`；今日为 ABP 默认内存实现，应用池回收即丢。换 Redis 后与 D1–D5 同发，便于断连风暴场景下缓存与进程生命周期解耦。

**备选否决**：SignalR Redis 背板（超出本 change；单机 IIS/Kestrel 无多节点 Hub 需求）；继续内存缓存（用户要求加 Redis）。

**失败行为**：Redis 不可达时宿主启动或首次缓存 I/O 失败须可观测（日志）；不以静默回退内存掩盖运维未装 Redis（避免双轨语义）。开发机若未装 Redis，须先装 tporadowski/redis 或显式改连接串指向可用实例。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 项目管理页状态不实时 | 产品接受；手动刷新 / 重进页 |
| 用户不知道要刷新 | 可选加「刷新」按钮（无自动轮询） |
| 断连 upsert 仍与 GovSync 争库 | 另开 change |
| 拉长 ClientTimeout 掩盖真死连接 | KeepAlive &lt; ClientTimeout；可配置 |
| Redis 未装 / 未启动导致缓存失败 | 部署清单要求 tporadowski/redis + 6379；启动或健康检查日志提示 |
| `maxmemory 100mb` 触顶丢缓存 | `allkeys-lru`；权威在线状态仍以 SQLite `ClientOnlineStatus` 为准 |
| tporadowski 非官方长期维护 | 接受现场 Windows 约束；连接协议兼容，日后可换官方 Redis / Memurai |

## Migration Plan

1. 现场安装并启动 tporadowski/redis；确认 `maxmemory 100mb`、端口 6379。
2. 发布含 D1–D7 的包；回收应用池。
3. 验证：浏览器 Network 无对 `/hubs/devicestatus` 的协商；项目管理无定时请求；桌面端仍能上报状态；`redis-cli INFO memory` 可见 `UM:` 键增长且 used_memory 受 100mb 约束。
4. 观察断连 ERR 噪声下降。
5. 回滚：回退应用版本；可选停 Redis（回退旧包后缓存再回内存实现）。

## Open Questions

- （无阻塞）「刷新」是沿用现有筛选/翻页触发重载，还是加独立按钮——实现时若页上已无明确刷新入口，补一个按钮。
