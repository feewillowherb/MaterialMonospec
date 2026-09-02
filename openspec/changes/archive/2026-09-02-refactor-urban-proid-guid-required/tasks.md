## 1. Branch & setup

- [x] 1.1 在 `repos/UrbanManagement` 自 `dev-urban-entity-semantic` 创建并切换分支 `refactor-urban-proid-guid-required`（Mode B）
- [x] 1.2 在 `repos/MaterialClient` 自 `dev-urban-entity-semantic` 创建同名分支
- [x] 1.3 阅读 [`design.md`](./design.md) 与 P2 范围（[04 §P2](../../docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md)）

## 2. UrbanManagement — Entity & EF migration

- [x] 2.1 `UrbanWeighingRecord.ProId`：`Guid?` → non-nullable `Guid`；migration 将现有 `NULL` 回填为 `Guid.Empty`
- [x] 2.2 `UrbanPassageRecord.ProId`：`Guid?` → non-nullable `Guid`；migration 将现有 `NULL` 回填为 `Guid.Empty`
- [x] 2.3 `ClientOnlineStatus.ProId` / `ClientDeviceOnlineStatus.ProId`：`string` → `Guid`；migration **删除** `Guid.TryParse` 失败的行，再改列类型
- [x] 2.4 `GovSyncData.ProId`：`string?` → non-nullable `Guid`；migration 可解析则转换，否则 `Guid.Empty`
- [x] 2.5 更新 `UrbanManagementDbContext` 配置（列类型、索引/唯一约束 `(ProId, ClientId)` 等）
- [x] 2.6 新增 EF migration 并本地验证 Up/Down

## 3. UrbanManagement — Receive & domain

- [x] 3.1 `UrbanWeighingRecordAppService.ReceiveAsync`：拒绝缺失/`Guid.Empty` 的 `ProId`；DTO 改为 required `Guid`
- [x] 3.2 Passage receive / `UrbanPassageRecord.FromReceive`（或等价工厂）：`ProId` required；拒绝 `Guid.Empty`
- [x] 3.3 更新 `UrbanWeighingRecordDto` / passage receive DTO 与 AutoMapper（如有）
- [x] 3.4 查询/列表：按需过滤 `ProId == Guid.Empty` 的历史脏行（若 UI 暴露）

## 4. UrbanManagement — Device online status & SignalR

- [x] 4.1 `DeviceStatusHub` / 在线态 Service：`UploadStatus` 持久化前 `Guid.TryParse(message.ProId)`；失败则 skip upsert 并 log
- [x] 4.2 更新 `ClientOnlineStatus` / `ClientDeviceOnlineStatus` 读写与 `GetClientDevicesAsync` 等查询（`Guid` 比较）
- [x] 4.3 确认 disconnect / offline 逻辑仍按 `(ProId, ClientId)` 正确匹配
- [x] 4.4 `DeviceStatusMessage` 实体/DTO：**wire 仍为 string**；仅 DB 层用 `Guid`

## 5. MaterialClient — Submit & upload

- [x] 5.1 `UrbanWeighingRecordSubmitDto.ProId` / `UrbanPassageSubmitDto.ProId`：required non-nullable `Guid`
- [x] 5.2 `UrbanServerUploadService.SubmitRecordAsync`：从 `LicenseInfo.ProjectId` 赋值；`Empty` 或缺失 license 时不上传并 log
- [x] 5.3 `UrbanPassageUploadService`（或等价）：同上必填 `ProId`
- [x] 5.4 `DeviceStatusEventHandler`：`DeviceStatusMessage.ProId` 保持 string（`ProjectId.ToString()`）

## 6. Tests & verify

- [x] 6.1 UrbanManagement Core.Tests：Receive 拒绝 empty ProId；在线态 Guid parse；migration 相关 fixture（若适用）
- [x] 6.2 MaterialClient 相关测试：Submit DTO required ProId；无 license 不上传
- [x] 6.3 `dotnet build` / 相关测试通过（UM + MC）
- [x] 6.4 squash 合入 `dev-urban-entity-semantic`（UrbanManagement + MaterialClient）

## 7. Monospec（本仓）

- [x] 7.1 `openspec validate refactor-urban-proid-guid-required --strict` 通过
- [x] 7.2 准备 archive（initiative 收尾或本 change 完成后用户确认）

**后续 change（不在本 tasks 范围）**：`update-urban-weighing-record-site-type-enum`、`rename-gov-project-enable-sync-to-is-sync-enabled`；intake [INT-005](../../docs/intake/2026-09/INT-005-urban-entity-accesscode-rename.md)、[INT-006](../../docs/intake/2026-09/INT-006-legacy-gov-sync-reimplementation.md)。
