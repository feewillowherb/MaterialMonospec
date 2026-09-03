## 1. Branch and model

- [ ] 1.1 Mode A：在 `UrbanManagement` 自 trunk 创建并切换分支 `add-urban-legacy-weighing-ingest`（首次改代码前）
- [ ] 1.2 新增枚举 `UrbanWeighingIngestSource`（Modern/Legacy/Migrated）与实体属性 `UrbanWeighingRecord.IngestSource`（non-nullable，默认 Modern）
- [ ] 1.3 EF migration：存量行 `IngestSource=0`；输出 DTO 如需要则暴露同名字段

## 2. Reject staging

- [ ] 2.1 新增 `LegacyWeighingRejectStaging`（或最终定名）实体：RejectedAt、RejectReason、AccessCodeAttempted、PlateNumber、PayloadJson、SnapImagesBase64Json 等；**仅主键索引**
- [ ] 2.2 DbContext + migration；Repository 按 `minimal-di` 注册门槛接入

## 3. Receive / IngestSource 防伪

- [ ] 3.1 `ReceiveAsync`（及创建路径）：对外 Modern 路径强制 `IngestSource=Modern`；支持内部/DTO 在合法调用下写入 Legacy
- [ ] 3.2 单测：Modern Receive 忽略伪造 Legacy；幂等更新不改写已有 IngestSource（若触及）

## 4. LegacyGovSyncAppService 实装

- [ ] 4.1 移除 WIP 501 stub；实现校验：忽略 `fdBuildLicenseNo`；无/未知 `buildLicenseNo` → 写拒收暂存 + 失败响应
- [ ] 4.2 重量：`grossWeight>0` 覆盖 `goodsWeight`；`siteType` 映射 `UrbanSiteType`；查 `GovProject` → ProId/ProName（type-owned / static，无 MappingService）
- [ ] 4.3 `IFileService` 存图，**全部 `AttachType.Lpr`** → AttachmentIds
- [ ] 4.4 `ClientRecordId = Guid.NewGuid()`；`IngestSource=Legacy`；调用 `ReceiveAsync`；**禁止** Insert `GovSyncData`
- [ ] 4.5 成功/失败均返回旧版 `{ success, msg, code }`（成功 code=200）

## 5. Controller

- [ ] 5.1 `LegacyApiController`：`[AllowAnonymous]`（或不鉴权等价）；保持薄解析；去掉永久 WIP 501 行为
- [ ] 5.2 确认路由仍为 `POST /Api/Post`

## 6. Tests and ops notes

- [ ] 6.1 单测：成功入库 + Lpr 附件；未知码拒收暂存含 Base64；凡东码 alone 拒收；无 GovSyncData insert
- [ ] 6.2 文档/运维说明（可写在 change 备注或调研夹指针）：同机异端口 Serve→UM HTTP 转发；停 Serve 落盘与出站（Q5）；**不含** INT-007 批迁

## 7. Monospec / intake

- [ ] 7.1 提交本 change 工件；INT-006 孵化记录注明 `proposed` / change 名（勿动 INT-007）
- [ ] 7.2 Apply 完成后 Mode A squash 入 UrbanManagement trunk；归档前跑 `/opsx-verify-agents`（若适用）
