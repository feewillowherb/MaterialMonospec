## 1. Branch (Mode A)

- [ ] 1.1 UrbanManagement：自 trunk 创建并切换分支 `rename-urban-addtime-column-to-creationtime`
- [ ] 1.2 MaterialMonospec（同会话改 openspec/tasks 勾选时）：同名分支自 trunk 切出

## 2. EF + migration

- [ ] 2.1 删除 `UrbanManagementDbContext` 四处 `HasColumnName("AddTime")` 及 F3 过渡注释
- [ ] 2.2 称重索引：去掉 `HasDatabaseName("IX_UrbanWeighingRecords_AddTime")`（或 rename 为 `IX_UrbanWeighingRecords_CreationTime`）
- [ ] 2.3 手写 migration：`GovProjects` / `GovSyncData` / `UrbanWeighingRecords` / `AttachmentFiles` 的 `RenameColumn` `AddTime` → `CreationTime`；同步 rename 称重 AddTime 索引；**勿**改 `UrbanPassageRecords`

## 3. DTO / 编译跟随

- [ ] 3.1 `GovProjectDto`、`GovSyncDataDto`、`UrbanWeighingRecordOutputDto`：`AddTime` → `CreationTime`；`From*` 赋 `entity.CreationTime`
- [ ] 3.2 更新 `GovProjectUpdateDto` 等注释中的 AddTime；`UrbanWeighingRecordDtos` 附件时间注释改为 `CreationTime`
- [ ] 3.3 `wwwroot/js/site.js` 示例 `sorting` 改为 `CreationTime desc`
- [ ] 3.4 全仓搜 UM `AddTime`（排除历史 migration 正文与 Designer 旧快照）：仅新 snapshot / 新 migration 允许 `CreationTime`

## 4. Tests

- [ ] 4.1 更新断言输出 DTO / JSON `addTime` 的测试为 `CreationTime` / `creationTime`
- [ ] 4.2 跑 UrbanManagement.Core.Tests 相关用例

## 5. Verify

- [ ] 5.1 `openspec validate rename-urban-addtime-column-to-creationtime --strict`
- [ ] 5.2 用本地库副本确认四表列为 `CreationTime`、称重行数未丢（可复用 `urban-db-accesscode-migrate` 工作副本或同构 probe）
- [ ] 5.3 确认无 MaterialClient 改动
