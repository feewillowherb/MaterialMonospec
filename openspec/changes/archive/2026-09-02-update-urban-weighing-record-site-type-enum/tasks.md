## 1. Branch & setup

- [x] 1.1 在 `repos/UrbanManagement` 自 `dev-urban-entity-semantic` 创建并切换分支 `update-urban-weighing-record-site-type-enum`（Mode B）
- [x] 1.2 在 `repos/MaterialClient` 自 `dev-urban-entity-semantic` 创建同名分支
- [x] 1.3 阅读 [`design.md`](./design.md) 与 P2 D15（[04 §P2](../../docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md)）

## 2. UrbanManagement — Entity & migration

- [x] 2.1 `UrbanWeighingRecord.SiteType`：`string?` → non-nullable `UrbanSiteType`（默认 `Construction`）
- [x] 2.2 更新 `UrbanManagementDbContext`：移除 `HasMaxLength(50)` string 配置，改为 enum/int
- [x] 2.3 新增 EF migration：历史 string 映射（`1`/`2`/枚举名等）→ int；不可识别 → `Construction`；再 AlterColumn
- [x] 2.4 Receive DTO / `UrbanWeighingRecordDto`：`SiteType` 改为 `UrbanSiteType`

## 3. UrbanManagement — Outbound converters

- [x] 3.1 `XiaoshanWeighbridgeConverter` 增加 `SiteType(UrbanSiteType)`：`Disposal`→`"2"`，否则 `"1"`
- [x] 3.2 `GovSyncWeightPayload.FromRecord`：用 converter，禁止透传自由文本
- [x] 3.3 确认卡口/成品 converter 行为不变

## 4. MaterialClient — Submit

- [x] 4.1 `UrbanWeighingRecordSubmitDto.SiteType`：改为 `UrbanSiteType`
- [x] 4.2 `UrbanServerUploadService`：从 Scale LPR 行 `UrbanSiteType` 赋值；缺失则 `Construction`
- [x] 4.3 确认 JSON `siteType` 为字符串 enum 名（与服务端一致）

## 5. Tests & verify

- [x] 5.1 UM：Receive/DTO enum；`GovSyncWeightPayload` Disposal→`"2"` / Construction→`"1"`
- [x] 5.2 MC：Submit DTO / 上传赋值（若有现成测试则更新）
- [x] 5.3 `dotnet build` / 相关测试通过（UM + MC）
- [x] 5.4 squash 合入 `dev-urban-entity-semantic`（UrbanManagement + MaterialClient）

## 6. Monospec（本仓）

- [x] 6.1 `openspec validate update-urban-weighing-record-site-type-enum --strict` 通过
- [x] 6.2 准备 archive（initiative 收尾或本 change 完成后用户确认）

**后续 change（不在本 tasks 范围）**：`rename-gov-project-enable-sync-to-is-sync-enabled`、`refactor-gov-sync-data-strong-types`；intake [INT-005](../../docs/intake/2026-09/INT-005-urban-entity-accesscode-rename.md)、[INT-006](../../docs/intake/2026-09/INT-006-legacy-gov-sync-reimplementation.md)。
