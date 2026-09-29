## Why

`fix-urban-signalr-disconnect-storm` 把连接态改成 Redis 主存、热路径零 EF 后卡顿已缓解，但离线壳与 online 共用短 TTL（约 2× ClientTimeout），断连约两分钟后徽章从「离线」变成「未注册」；Redis 清空后也无法从 SQLite 恢复。产品需要：**离线状态在 Redis 保留一周**，并 **每天把缓存快照刷回 EF**，管理页在 Redis miss 时可回源显示离线。

## What Changes

- **离线 Redis TTL = 7 天**（可配置）：断连写 `IsConnected=false` 时使用长 TTL；**在线**条目仍用短 live TTL，防幽灵在线
- **connection registry** 保留期至少覆盖离线 TTL，避免列表扫不到离线条目
- **每日一次** BackgroundWorker：将 Redis 连接（及约定的设备当前态）快照 upsert 到 `ClientOnlineStatus` / 相关表；**禁止**在 Hub connect/disconnect/`UploadStatus` 热路径写 EF
- **查询**：项目管理徽章仍优先读 Redis；**Redis miss 时回源 EF** 已登记实例 → 显示离线（非未注册）；两边皆无 → 未注册
- 修订上一 change「接受连接丢失、禁止刷库 / 禁止 SQLite 回源」的产品语义（热路径零 EF 不变）

## Capabilities

### New Capabilities

- `urban-client-status-ef-snapshot`: 日批将 Redis 客户端连接/离线快照同步到 EF；可配置周期与保留天数

### Modified Capabilities

- `device-online-status-persistence`: 离线 Redis 保留一周；查询 Redis miss 可回源 EF 离线壳；热路径仍禁止 EF upsert
- `urban-redis-distributed-cache`: 区分 online live TTL 与 offline retention TTL；registry 与离线保留对齐

## Impact

- **子仓库**：`repos/UrbanManagement`（`DeviceStatusService` TTL、查询合并、BackgroundWorker、`SignalROptions` / appsettings、可选设备快照）
- **桌面端**：无协议变更
- **运维**：Redis 仍必需；日批依赖 Redis 可读；EF 为冷备份与徽章回源
- **分支**：Mode A — `update-urban-offline-retention`
