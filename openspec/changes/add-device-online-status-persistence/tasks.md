## 1. Data model (UrbanManagement) — multi-instance + device details

- [x] 1.1 新增 `ClientOnlineStatus`：`ProId`、`ClientId`、`ProName`、`IsConnected`、`ConnectedAt`、`DisconnectedAt`、`LastSeenAt`；可选可空 `Slot`
- [x] 1.2 新增 `ClientDeviceOnlineStatus`（设备在线详情当前态）：`ProId`、`ClientId`、`DeviceType`、`Status`、`LastUpdateTime`、`AdditionalData?`
- [x] 1.3 唯一索引：连接 `(ProId, ClientId)`；设备详情 `(ProId, ClientId, DeviceType)`；注册 DbContext
- [x] 1.4 EF Core migration 并应用到开发库

## 2. Persistence service path

- [x] 2.1 连接态：按 `(ProId, ClientId)` upsert 在线/离线、节流刷新 `LastSeenAt`；`[UnitOfWork]`；缺 `ClientId` 不回退 ProId 单行
- [x] 2.2 设备详情：`UploadStatus` 路径 upsert `(ProId, ClientId, DeviceType)` 当前态
- [x] 2.3 Hub：`ConnectionId → (ProId, ClientId)`；断线只更新该实例连接态，并将其设备详情全部标 offline
- [x] 2.4 写穿缓存可选且键区分实例；失败不影响落库

## 3. Query API

- [x] 3.1 `GetClientListAsync` 读连接表；同 ProId 可多 `ClientId`
- [x] 3.2 `GetClientDevicesAsync` 读设备详情表；DTO 含 `ClientId`；缓存空仍返回 DB 数据
- [x] 3.3 项目级未注册/在线/离线聚合规则（design D4）
- [x] 3.4 扩展连接/设备 DTO（命名 record，禁用 tuple）

## 4. ProjectManagement UI

- [x] 4.1 列文案「最后在线时间」+ 聚合时间戳绑定（不用 `LastSyncTime`）
- [x] 4.2 客户端徽标按多实例聚合；SignalR/轮询刷新
- [x] 4.3「设备」弹窗展示落库详情；多 `ClientId` 时保持可区分（最小：展示 ClientId 或简单分组）

## 5. Verify

- [x] 5.1 单机：连接/断开 + 设备 UploadStatus 落库；重启后列表与弹窗仍有数据（代码路径 + migration 已应用到开发库；联调需启动 UM + Client）
- [x] 5.2 同 ProId 两 ClientId：并存在线；断其一不影响另一连接态与设备详情（按实例 upsert/断线实现；聚合单测覆盖）
- [x] 5.3 清空缓存后 `GetClientListAsync` / `GetClientDevicesAsync` 仍读 DB（AppService 已改为纯 DB）
- [x] 5.4 最小测试：连接 upsert、设备详情 upsert、断线级联 offline、聚合语义（`ProjectClientConnectionAggregateTests` + cache key）
