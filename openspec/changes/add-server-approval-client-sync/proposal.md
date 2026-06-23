## Why

UrbanManagement Web 端 `ApproveAsync` 审批成功后，MaterialClient 现场仍可能显示「待审批」并再次本地审批，经 `ReceiveAsync` upsert 覆盖服务端结果，造成双端重复审批与数据不一致。当前同步链路仅为客户端 → 服务端，缺少服务端审批结论下行到客户端的机制。

## What Changes

- 在 `UrbanWeighingRecord` 新增 `ServerApprovedAt`、`ClientApprovalAckAt` 时间戳，用于跟踪「服务端已审批」与「客户端已确认应用」。
- Web `ApproveAsync` 成功时写入 `ServerApprovedAt`，并通过 SignalR 向对应项目客户端推送审批同步消息。
- MaterialClient 收到推送后更新本地记录（`IsAnomaly=false`、车牌/重量等），并调用 ACK API 写入 `ClientApprovalAckAt`。
- 客户端重连或启动时提供拉取接口，补发 `ServerApprovedAt != null && ClientApprovalAckAt == null` 的待同步记录。
- 客户端列表对已由服务端审批且本地已同步的记录禁用「审批」入口。
- **冲突策略从简**：若服务端已审批而客户端再次本地审批并上云，或推送/ACK 时序交错，**不强制拒绝或仲裁**；以最后成功写入的一端为准，任意结果均可接受。
- 不在本 change 中实现 Lrp 附件下行拉取（仅同步 plate/weight/异常状态与编辑历史）。

## Capabilities

### New Capabilities

- `server-approval-client-sync`: 服务端 Web 审批后通过 SignalR 推送与 ACK/拉取 API，将审批结论同步至 MaterialClient，含 `ServerApprovedAt` / `ClientApprovalAckAt` 状态跟踪。

### Modified Capabilities

- `urban-weighing-api`: 实体新增 `ServerApprovedAt`、`ClientApprovalAckAt`；`ApproveAsync` 写入审批时间戳；新增 ACK 与待同步拉取 API。
- `urbanmanagement-weighing-record-approval`: Web 审批成功后触发下行同步推送。
- `weighing-record-approval`: 客户端接收服务端审批同步、本地应用、ACK 与 UI 禁用逻辑。
- `signalr-device-status-upload`: Hub 或客户端连接扩展，支持向指定 ProId 客户端推送称重审批同步消息。

## Impact

| 区域 | 说明 |
|------|------|
| `UrbanManagement.Core` | 实体字段、`ApproveAsync`、ACK/拉取 AppService、SignalR 推送 |
| `UrbanManagement.EntityFrameworkCore` | EF 迁移新增两列 |
| `UrbanManagement.App` | SignalR Hub 扩展或推送路由 |
| `MaterialClient.Urban` | SignalR 订阅 Handler、本地 Service 应用审批同步、ACK 调用 |
| `MaterialClient.Common` | 可选：共享 DTO / 事件类型 |
| OpenSpec | 上述 capability delta specs |
| 政府同步 Worker | 无逻辑变更；仍依赖 `IsAnomaly == false` |
