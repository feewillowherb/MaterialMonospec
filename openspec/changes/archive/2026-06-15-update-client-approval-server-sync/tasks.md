## 1. UrbanManagement 服务端 ReceiveAsync upsert

- [ ] 1.1 在 `UrbanWeighingRecordAppService.ReceiveAsync` 去重分支提取 `ApplyDuplicateReceiveUpdateAsync`（或等价私有方法），按 design D2 更新 `PlateNumber`、`TotalWeight`、`IsAnomaly`、`AnomalyReason`、客户端同步元数据
- [ ] 1.2 当 `input.IsAnomaly == false` 时复位 `SyncType = 0`、`RetryCount = 0`（对齐 Web `ApproveAsync`）
- [ ] 1.3 若 input `ExtraProperties` 含 `"EditHistory"`，替换实体 `ExtraProperties["EditHistory"]`（design D3）
- [ ] 1.4 去重路径移除 `LinkAttachmentsAsync` 调用；`AttachmentIds` 仅在新建记录路径处理（design D4）

## 2. UrbanManagement 单元测试

- [ ] 2.1 新增测试：`ReceiveAsync` 重复 `ClientRecordId` + 修正字段 → 已有记录被更新、`SyncType`/`RetryCount` 复位
- [ ] 2.2 新增测试：重复 receive 且 `isAnomaly` 从 `true` 变为 `false` → 存储值更新、无服务端异常重算
- [ ] 2.3 新增测试：重复 receive payload 与存储一致 → 仍返回已有 Id、不插入新记录
- [ ] 2.4 新增测试：`ExtraProperties["EditHistory"]` 在去重路径被正确写入
- [ ] 2.5 新增测试：重复 receive 携带 `AttachmentIds` → 已有附件关联不变、无新增 join 行

## 3. MaterialClient.Urban 上传 DTO

- [ ] 3.1 在 `UrbanServerUploadService` 中按 extension `IsAnomaly` 条件设置 `SyncType`（非异常 `0`，异常不触发政府同步复位，design D5）
- [ ] 3.2 确认审批后 `AppendEditEntryAsync` 写入的 `EditHistory` 已包含在 `ExtraProperties` 并随重传发送（现有逻辑验证，缺口则补）
- [ ] 3.3 （可选优化）重传场景（曾 `Synced` 后审批复位 `Pending`）跳过本地附件上云，减少无效带宽；服务端去重路径已保证不更新附件

## 4. 验证

- [ ] 4.1 运行 `UrbanManagement.Core.Tests` 全部通过
- [ ] 4.2 手工或集成验证：首次上云（异常）→ 客户端审批 → 轮询重传 → Web 列表显示修正后车牌/重量且 `IsAnomaly=false`
- [ ] 4.3 运行 `openspec validate update-client-approval-server-sync --strict`
