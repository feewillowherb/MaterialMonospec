## Context

GovSyncData 语义与政府快照绑定，不适合直接承载工业 WeighingRecord。新建 Urban 专用表。

## Goals / Non-Goals

**Goals**

- 端到端一条记录可从客户端上传并在 UrbanManagement 查询
- DTO 与 `WeighingRecord` 字段对齐（重量、时间、车牌等按实体实际字段映射）

**Non-Goals**

- 批量历史迁移
- OAuth / 用户登录

## Decisions

1. **表** `Urban_WeighingRecord`：Id、DeviceId、ClientRecordId（客户端 Guid）、Weight、PlateNumber、WeighedAt、ProductCode、WeighingMode、RawJson（可选）、ReceivedAt。
2. **API** `POST /api/urban/weighing-records`，body 为 `CreateUrbanWeighingRecordDto`；幂等键 `ClientRecordId` + `DeviceId`。
3. **客户端** `UrbanUploadBackgroundService` 每 30s 扫描 Pending；Polly 重试 3 次。
4. **映射**：AutoMapper / 手动 Map 从 `WeighingRecord` → DTO。
5. **查询** `GET /api/urban/weighing-records?deviceId=&page=` 供管理端。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 字段不一致 | OpenSpec specs 列出必填 DTO 字段 |
| 重复上传 | 服务端唯一索引 (DeviceId, ClientRecordId) |
