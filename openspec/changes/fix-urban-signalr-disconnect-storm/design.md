## Context

- 现场 `Logs/log-20260911.txt`：`DeviceStatusHub` 成批 `ClientTimeoutInterval` 断连；断连路径 EF/`SaveChanges` 大量 `TaskCanceledException`；项目管理页浏览器再连 Hub。
- 产品决定：Web 不订阅 DeviceStatus SignalR、不要轮询；**用 Redis 做连接/设备当前态主存以减轻 SQLite EF 压力**；**接受连接丢失**（UM 或 Redis 重启后状态清空，等客户端重连）。

## Goals / Non-Goals

**Goals:**

- SignalR 热路径（connect / disconnect / `UploadStatus`）**零 EF 写**；当前态只进 Redis。
- 管理页连接徽章与设备当前态查询以 Redis 为准；手动刷新 / 重进页。
- 本机 Redis：tporadowski/redis、端口 **6379**、`maxmemory 100mb`。
- 可配置 KeepAlive / ClientTimeout；去掉 Web DeviceStatus Hub 与轮询。
- 保留桌面端 `MapHub<DeviceStatusHub>` 与 Blazor `MapBlazorHub`。

**Non-Goals:**

- 删除 `DeviceStatusHub` 或改 MaterialClient 协议。
- 定时轮询；SignalR Redis **背板**（Hub scale-out）。
- GovSync UoW/WAL。
- 强制 drop `ClientOnlineStatus` / `ClientDeviceOnlineStatus` 表或做数据迁移清理（可留壳，热路径不用）。
- 把连接态再异步刷回 SQLite（半吊子方案；本 change 明确不要）。

## Decisions

### D1: Redis 主存连接与设备当前态（接受丢失）

**选择**：`UpsertClientConnectedAsync` / `UpsertClientDisconnectedAsync` / `UploadStatus` 设备详情与 LastSeen **只写 Redis**（`IDistributedCache` 或等价）。断连时标记离线或删除在线键并刷新 TTL；**不**调用 `IRepository` / `SaveChanges`。

查询（`GetClientConnections*`、`GetClientDevices*`、项目管理聚合）：**只读 Redis**。缺 key → 离线或未注册；**禁止**回源 SQLite「补全」实时徽章。

**接受丢失**：

- UM 应用池回收且 Redis 仍在 → 连接态可保留至 TTL（优于纯内存）。
- Redis 重启 / `FLUSH` / LRU 淘汰 → 管理页全员离线/未注册，直至桌面端重连。
- 幽灵在线：键带 TTL（建议 ≥ 2× `ClientTimeoutInterval`）；`UploadStatus` / 连接续期刷新 TTL。

**理由**：热路径打 SQLite 是断连风暴主因；产品接受易失态，Redis 才能真正减 EF 压力。

**备选否决**：仅把内存 cache 换成 Redis 仍先写库（减不了 EF）；断连写 Redis + 定时刷库（风暴后仍打库）。

### D2: Hub 路径尽力而为，失败分级

- Redis I/O 失败 → 可观测日志；不静默回退内存、不回退 EF。
- 广播 `ClientConnectionUpdate` 仍 best-effort 供非 Web 订阅者；Web 不再入组。
- Hub `OnDisconnectedAsync` 尽快返回（无 EF await）。

### D3: 可配置 SignalR 心跳与客户端超时

`KeepAliveIntervalSeconds` 默认 15，`ClientTimeoutIntervalSeconds` 默认 60（须大于 KeepAlive）。应用到 `AddSignalR` 与 Blazor hub options。

### D4: 不做断连写库 / 不做刷库队列

热路径零 EF；不引入「最终一致刷 SQLite」。

### D5: 移除 Web DeviceStatus SignalR，不引入轮询

删除 `ProjectManagement.razor` 的 HubConnection / 订阅 / `StartFallbackPolling`。列表与徽章仅在导航或用户触发刷新时经 AppService（读 Redis）。若无显式刷新入口则补「刷新」按钮。**禁止**后台定时轮询。

### D6: 保留服务端 Hub 与 Blazor 电路

`MapHub<DeviceStatusHub>` / `MapBlazorHub` 不变。

### D7: Redis 基础设施（非背板）

`Volo.Abp.Caching.StackExchangeRedis`（ABP 10.0.1），`DependsOn` `AbpCachingStackExchangeRedisModule`；`Redis:Configuration` 默认 `127.0.0.1:6379`；保留 `KeyPrefix = "UM:"`。

现场 [tporadowski/redis](https://github.com/tporadowski/redis)：

```text
maxmemory 100mb
maxmemory-policy allkeys-lru
```

Redis 不可达 → 启动或首次缓存 I/O 失败可观测；无静默内存回退。

### D8: 遗留 SQLite 在线表

表与实体可保留，避免本 change 做破坏性 migration。热路径与实时查询 **MUST NOT** 读写这些表作为权威源。历史行可忽略；不要求本 change 清空。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 重启后徽章全离线 | 产品接受；客户端自动重连写回 Redis |
| Redis 宕机则无在线态 | 部署强制 Redis；失败可观测 |
| TTL/LRU 导致误显示离线 | TTL ≥ 2× ClientTimeout；上报续期 |
| 100mb 触顶淘汰 | `allkeys-lru`；在线键短小；监控 used_memory |
| Web 状态不实时 | 手动刷新（已接受） |

## Migration Plan

1. 安装并启动 tporadowski/redis（6379、`maxmemory 100mb`）。
2. 发布本 change；回收应用池。
3. 验证：断连/上报无 SQLite `ClientOnlineStatuses` 写；Redis 有 `UM:` 键；管理页无 `/hubs/devicestatus`、无 30s 轮询；手动刷新读 Redis；重启 Redis 后徽章清空直至重连。
4. 回滚：回退应用版本（旧版再写 SQLite）；Redis 可保留。

## Open Questions

- （无阻塞）显式「刷新」按钮 vs 仅筛选/翻页触发——页上无入口则补按钮。
- （无阻塞）设备弹窗是否完全只读 Redis（推荐是）；若保留偶发读库须在 tasks 中显式否决。
