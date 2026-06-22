## Context

当前 Urban 称重同步为**客户端 → 服务端**单向：

```
客户端上云 ReceiveAsync → Web ApproveAsync（服务端 IsAnomaly=false）
客户端本地仍可能显示待审批 → 再次审批 → ReceiveAsync upsert 覆盖服务端
```

`update-client-approval-server-sync` 已支持客户端审批后 upsert 服务端，但未解决 Web 先审批、客户端后审批的双端竞态。项目已有 `DeviceStatusHub` 与 MaterialClient SignalR 连接，可复用作为下行通道。

**用户约束**：审批同步冲突**不需要严谨仲裁**；服务端已审、客户端再审，或推送/ACK 时序交错时，**任意一方最终结果均可接受**，不引入 409 拒绝或复杂 merge 策略。

## Goals / Non-Goals

**Goals:**

- `UrbanWeighingRecord` 新增 `ServerApprovedAt`、`ClientApprovalAckAt` 跟踪下行同步状态。
- Web `ApproveAsync` 成功后写入 `ServerApprovedAt`，SignalR 推送至对应 `ProId` 的客户端连接。
- 客户端应用服务端审批结论（plate/weight、`IsAnomaly=false`），调用 ACK API 写入 `ClientApprovalAckAt`。
- 客户端重连/启动时拉取待同步记录（`ServerApprovedAt != null && ClientApprovalAckAt == null`）。
- 本地已应用服务端审批的记录禁用「审批」入口。

**Non-Goals:**

- Lrp / UrbanPhoto 附件下行拉取（本 change 仅同步业务字段与异常状态）。
- `ReceiveAsync` 对冲突 payload 的严格拒绝或版本仲裁。
- 新建独立 Hub（优先扩展 `DeviceStatusHub`）。
- 修改政府同步 Worker 逻辑。

## Decisions

### D1: 用两个时间戳而非 bool 表示下行状态

**选择**：`ServerApprovedAt`（Web 审批成功时写）、`ClientApprovalAckAt`（客户端确认应用后写）。

**理由**：可派生「待下发」=`ServerApprovedAt != null && ClientApprovalAckAt == null`；支持拉取 API 与运维排查；比单一 bool 更可观测。

**备选**：`ApprovalClientSyncStatus` 枚举 — 过度设计，拒绝。

### D2: SignalR 推送 + 拉取兜底

**选择**：`ApproveAsync` 成功后向该记录 `ProId` 关联的在线客户端连接发送 `WeighingRecordApproved` 消息；客户端 SignalR 重连或应用启动时调用拉取 API 补发。

**载荷**（命名 `record`，禁止 tuple）：

```csharp
record WeighingRecordApprovedPush(
    long ClientRecordId,
    string PlateNumber,
    decimal TotalWeight,
    DateTime ServerApprovedAt,
    string? EditHistoryJson
);
```

**理由**：复用现有 SignalR 基础设施；推送实时，拉取覆盖离线。

### D3: 冲突策略从简（last-write-wins）

**选择**：

- `ReceiveAsync` **保持现有 upsert 行为**，不因 `ServerApprovedAt` 已设置而拒绝客户端 payload。
- 客户端收到服务端推送后应用本地状态；若操作员已在审批弹窗中，提示后关闭并刷新。
- 双端审批结果不一致时，**以最后成功持久化的一方为准**，不记录冲突错误、不强制回滚。

**理由**：用户明确任意结果可接受；避免增加运维复杂度。

**备选**：`ReceiveAsync` 409 拒绝 — 用户不要求，拒绝。

### D4: ACK API

**选择**：`POST /api/app/urban-weighing-record/ack-approval-sync`，body 含 `ClientRecordId`；服务端校验记录存在且 `ServerApprovedAt != null` 后写入 `ClientApprovalAckAt = DateTime.UtcNow`。

**理由**：明确「客户端已应用」边界；拉取 API 可查询 `ServerApprovedAt != null && ClientApprovalAckAt == null`。

### D5: 客户端本地应用逻辑

**选择**：Service 层（UoW 内）`ApplyServerApprovalAsync`：

1. 更新 `WeighingRecord.PlateNumber` / `TotalWeight`
2. `UrbanWeighingExtension.IsAnomaly = false`，清空 `AnomalyReason`
3. `SyncStatus = Synced`（服务端已是最新审批结论）
4. 可选 merge `EditHistory`（若推送携带 JSON，append `Source=Server` 条目；与本地历史冲突时不仲裁）
5. 调用 ACK API
6. 发布 `ServerApprovalSyncedEventData` 刷新 UI

**理由**：符合 ViewModel → Service 架构约束；不在 UI 线程阻塞 HTTP。

### D6: 扩展 DeviceStatusHub 而非新建 Hub

**选择**：在 `DeviceStatusHub` 增加服务端 `PushWeighingRecordApprovedAsync`（或 Hub 上下文向连接组发送）；客户端 `DeviceStatusSignalRClient` 注册 `OnWeighingRecordApproved` 回调。

**理由**：同一 ProId 连接已存在；减少端点与认证配置重复。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| SignalR 推送失败，客户端长时间显示待审批 | 重连拉取 API；列表刷新时可选触发拉取 |
| 双端审批 plate/weight 不一致 | 用户接受 last-write-wins；不强制一致 |
| Web 替换 Lrp 后客户端本地无图 | 本 change 不拉附件；已知限制 |
| `ClientApprovalAckAt` 写入前客户端崩溃 | 下次启动拉取 API 重新应用（幂等） |

## Migration Plan

1. EF 迁移：`Urban_WeighingRecord` 新增 `ServerApprovedAt`、`ClientApprovalAckAt`（nullable datetime）。
2. 部署 UrbanManagement（实体、ApproveAsync、ACK/拉取 API、Hub 推送）。
3. 部署 MaterialClient.Urban（SignalR 订阅、ApplyServerApproval、ACK 调用）。
4. 历史已审批记录：`ServerApprovedAt` 为 null；不影响政府同步。可选运维脚本回填（非本 change 范围）。
5. 回滚：移除推送与客户端 Handler；列可保留 nullable。

## Open Questions

（无 — 冲突策略已按用户要求从简。）
