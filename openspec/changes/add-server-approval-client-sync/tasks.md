## 1. UrbanManagement — 实体与迁移

- [x] 1.1 `UrbanWeighingRecord` 新增 `ServerApprovedAt`、`ClientApprovalAckAt`（nullable `DateTime`）
- [x] 1.2 添加 EF Core 迁移并更新 `UrbanManagementDbContext` 列映射
- [x] 1.3 更新 `UrbanWeighingRecordOutputDto` / 相关 DTO 暴露两字段（只读输出）

## 2. UrbanManagement — ApproveAsync 与 ACK/拉取 API

- [x] 2.1 `ApproveAsync` 成功时写入 `ServerApprovedAt = UtcNow`，`ClientApprovalAckAt = null`
- [x] 2.2 实现 `AckApprovalSyncAsync(ClientRecordId)`：校验 `ServerApprovedAt != null`，幂等写入 `ClientApprovalAckAt`
- [x] 2.3 实现 `GetPendingServerApprovalSyncAsync(ProId)`：返回 `ServerApprovedAt != null && ClientApprovalAckAt == null` 的记录列表
- [x] 2.4 定义 `WeighingRecordApprovedPush` record 与 ACK/拉取 input/output DTO（禁止 tuple）
- [x] 2.5 补充 Core 层单元测试：Approve 写时间戳、ACK 幂等、拉取过滤、ACK 无 ServerApprovedAt 拒绝

## 3. UrbanManagement — SignalR 推送

- [x] 3.1 扩展 `DeviceStatusHub` 或 Hub 上下文：按 `ProId` 组推送 `WeighingRecordApproved` 消息
- [x] 3.2 `ApproveAsync` 成功后调用推送服务；推送失败不抛错、不回滚审批
- [x] 3.3 确认客户端连接已按 `ProId` 入组（若无则补充连接时分组逻辑）

## 4. MaterialClient.Urban — 下行同步应用

- [x] 4.1 定义 `WeighingRecordApprovedPush`（或与服务端共享的等价 DTO）及 `ServerApprovalSyncedEventData` 本地事件
- [x] 4.2 实现 `IServerApprovalSyncService.ApplyServerApprovalAsync`（UoW）：更新 plate/weight、`IsAnomaly=false`、清空 `AnomalyReason`、`SyncStatus=Synced`、可选 merge EditHistory
- [x] 4.3 `DeviceStatusSignalRClient` 注册 `WeighingRecordApproved` 回调，转发至 `ApplyServerApprovalAsync`
- [x] 4.4 应用成功后调用 Refit `AckApprovalSyncAsync`；失败记录日志，本地状态仍已更新
- [x] 4.5 SignalR 重连与应用启动时调用拉取 API，逐条应用并 ACK

## 5. MaterialClient.Urban — UI 与审批入口

- [x] 5.1 `UrbanAttendedWeighingViewModel`：服务端审批已应用的行禁用「审批」按钮
- [x] 5.2 审批弹窗打开时若收到同记录服务端同步推送：提示、关闭弹窗、刷新列表
- [x] 5.3 订阅 `ServerApprovalSyncedEventData` 刷新列表

## 6. 验证

- [x] 6.1 Web 审批 → 在线客户端收到推送 → 本地 `IsAnomaly=false` → ACK 写入 `ClientApprovalAckAt`
- [x] 6.2 客户端离线 → Web 审批 → 客户端启动拉取 → 应用并 ACK
- [x] 6.3 服务端已审后客户端再次 `ReceiveAsync` upsert：不 409，按现有 upsert 行为（冲突从简）
- [x] 6.4 运行 `openspec validate add-server-approval-client-sync --strict`
