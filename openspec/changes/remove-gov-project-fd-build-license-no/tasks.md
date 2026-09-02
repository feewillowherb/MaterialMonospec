## 1. Branch & setup

- [x] 1.1 在 `repos/UrbanManagement` 自 `dev-urban-entity-semantic` 创建并切换分支 `remove-gov-project-fd-build-license-no`（Mode B）
- [x] 1.2 在 `repos/MaterialClient` 自 `dev-urban-entity-semantic` 创建同名分支（若该仓尚无 dev 基线则先自 trunk 建 `dev-urban-entity-semantic` 再切 change 分支）
- [x] 1.3 阅读 [`design.md`](./design.md) 与 P1 范围（[04 §P1](../../docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md)）

## 2. UrbanManagement — Entity & migration

- [x] 2.1 从 `GovProject` 实体删除 `FdBuildLicenseNo` 属性
- [x] 2.2 更新 `UrbanManagementDbContext`：移除 `FdBuildLicenseNo` 配置与 `IX_GovProjects_FdBuildLicenseNo` 索引
- [x] 2.3 新增 EF migration：drop column + drop index
- [x] 2.4 从 `GovProjectDto` / `CreateDto` / `UpdateDto` / `ProjectFormModel` 删除字段

## 3. UrbanManagement — Services & sync

- [x] 3.1 `GovProjectPullManager`：停止映射 `FdBuildLicenseNo`（HTTP client DTO 可保留反序列化）
- [x] 3.2 `GovProjectManager.ValidateAccessCodeAsync`：仅 `BuildLicenseNo` 查询
- [x] 3.3 `UrbanLicenseGenerator` / `UrbanLicenseRequestDto`：移除 claim 与参数
- [x] 3.4 `JwtAntiTamperService` / `JwtAntiTamperResult` / `DeviceStatusHub`：移除 `FdBuildLicenseNo`
- [x] 3.5 `GovProjectAppService` 搜索/filter 移除 `FdBuildLicenseNo` 条件
- [x] 3.6 Legacy DTO/Controller：不查询已删列；WIP 501 行为不变

## 4. UrbanManagement — Blazor UI

- [x] 4.1 `ProjectManagement.razor` / 表单：删除「施工许可证号」字段
- [x] 4.2 确认列表/详情不展示 `FdBuildLicenseNo`

## 5. MaterialClient

- [x] 5.1 从 `LicenseInfo` 实体、`LicenseInfoDto`、`LicenseCheckResult` 删除 `FdBuildLicenseNo`
- [x] 5.2 `JwtLicenseChecker` / Urban 模块启动写入：不再解析或持久化 `fdBuildLicenseNo` claim
- [x] 5.3 如有 EF migration（LicenseInfo 列），新增 drop column migration（N/A：实体已无该列）

## 6. Tests & verify

- [x] 6.1 更新 UrbanManagement Core.Tests：Pull、JWT、ValidateAccessCode、GovProject CRUD
- [x] 6.2 更新 MaterialClient 相关测试（若有）
- [x] 6.3 `dotnet build` / 相关测试通过
- [x] 6.4 squash 合入 `dev-urban-entity-semantic`（UrbanManagement + MaterialClient）

## 7. Monospec（本仓）

- [x] 7.1 `openspec validate remove-gov-project-fd-build-license-no --strict` 通过
- [ ] 7.2 准备 archive（initiative 收尾或本 change 完成后用户确认）

**后续 change（不在本 tasks 范围）**：`refactor-urban-proid-guid-required`、`update-urban-weighing-record-site-type-enum`、`rename-gov-project-enable-sync-to-is-sync-enabled`；intake [INT-005](../../docs/intake/2026-09/INT-005-urban-entity-accesscode-rename.md)。
