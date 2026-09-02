## 1. Branch (Mode A)

- [x] 1.1 UrbanManagement：自 trunk 创建并切换分支 `rename-urban-entity-buildlicenseno-to-accesscode`
- [x] 1.2 MaterialMonospec（若同会话改 openspec/tasks 勾选）：同名分支自 trunk 切出（仅文档/openspec 有改动时）
  - 注：本地曾 `git checkout` 写 HEAD Permission denied；分支已创建，工作区文件已落在 change 工件路径；合入前需确认 HEAD 在同名分支

## 2. Entity + EF

- [x] 2.1 `UrbanWeighingRecord`：`BuildLicenseNo` → `AccessCode`（注释：城管接入码）
- [x] 2.2 `UrbanPassageRecord`：属性 + 工厂/`From*` 对本字段赋值 → `AccessCode`（入参 DTO 仍可读 `BuildLicenseNo`）
- [x] 2.3 `GovSyncData`：`BuildLicenseNo` → `AccessCode`
- [x] 2.4 `UrbanManagementDbContext`：Weighing/Passage（及 GovSyncData 若有）Property 配置改为 `AccessCode`
- [x] 2.5 手写 migration：`UrbanWeighingRecords` / `UrbanPassageRecords` / `GovSyncData` 表 `RenameColumn` BuildLicenseNo → AccessCode（勿用错误启发式）

## 3. Compile follow-through（不改 DTO 名）

- [x] 3.1 AppService / Manager / File 路径：读写改为 `entity.AccessCode`；映射 `dto.BuildLicenseNo` ↔ `entity.AccessCode`
- [x] 3.2 `GovSyncWeightPayload` / Xiaoshan `FromRecord`：读 `record.AccessCode`，写出仍 `BuildLicenseNo` / `buildLicenseNo`
- [x] 3.3 `GovSyncDataDto` 等 From：DTO 属性名不变，源改为 `entity.AccessCode`
- [x] 3.4 全仓搜 Entity 侧残留 `BuildLicenseNo`；确认 DTO/协议/Legacy wire 未误改

## 4. Tests + sample

- [x] 4.1 更新构造 Entity 的测试为 `AccessCode = ...`
- [x] 4.2 协议/outbound 断言仍用 `buildLicenseNo`
- [x] 4.3 `SampleDataProvider`（若存在）GovSyncData 样例改用 `AccessCode`（仓库无 SampleDataProvider，跳过）
- [x] 4.4 跑 UrbanManagement.Core.Tests 相关用例（137 passed）

## 5. Verify

- [x] 5.1 `openspec validate rename-urban-entity-buildlicenseno-to-accesscode --strict`
- [x] 5.2 确认无 MaterialClient 改动；无 DTO/API JSON 键改名；Legacy 未恢复落库
