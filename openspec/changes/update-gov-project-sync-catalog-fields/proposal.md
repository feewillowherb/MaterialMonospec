## Why

BasePlatform.PublicApi 的 `ProjectCatalogController` 已扩展：仅返回 `ProductCode = 5001`（城管 Urban 产品）授权项目，并在响应中携带 `ProductCode`、`ProAddress`、`ShigongUnitName` 及授权对接字段。UrbanManagement 的 `GovProject` 实体与拉取同步链路仍停留在首版（仅 `ProId`/`ProName` + 占位初始化），无法持久化项目扩展信息，也无法在同步边界校验产品代码。

## What Changes

- 在 UrbanManagement 新增 `ProductCode` 枚举（`Standard = 5000`、`SolidWaste = 5010`、`Urban = 5001`），**仅用于同步边界校验与代码层常量**，不持久化到 `GovProject`。
- 扩展 `GovProject` 实体：新增 `ProAddress`、`ShigongUnitName`；保持现有字段与软删除语义不变。
- 更新 BasePlatform 拉取 DTO 与 `GovProjectPullAppService`：同步时校验 `productCode == 5001`；新记录插入完整字段；**已存在记录同步更新 API 提供的全部目录字段**（`ProName`、`ProAddress`、`ShigongUnitName`、`BuildLicenseNo`、`FdBuildLicenseNo`、`AuthEndTime`）；不再依赖 `IGovProjectInitFieldProvider`。
- 更新 `GovProjectDto` / `GovProjectCreateDto` / `GovProjectUpdateDto` 及 EF 迁移，使 CRUD 与列表可读写新字段。
- 同步更新 OpenSpec 中对 PublicApi 目录接口与 UrbanManagement 拉取同步的需求描述，与已上线 PublicApi 行为对齐。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `baseplatform-project-catalog-api`：目录 API 返回字段扩展为包含授权与项目扩展信息，且仅包含 `ProductCode = 5001` 授权项目。
- `gov-project-baseplatform-pull-sync`：拉取同步校验 `productCode`；新记录插入；**已存在记录 upsert 更新全部目录字段**。
- `urban-management-crud`：`GovProject` DTO 与实体映射扩展 `ProAddress`、`ShigongUnitName`；列表与 CRUD 行为兼容同步导入记录。

## Impact

- **UrbanManagement**（`repos/UrbanManagement/`）
  - `UrbanManagement.Core/Entities/GovProject.cs`
  - 新增 `UrbanManagement.Core/Enums/ProductCode.cs`（校验与常量，不入库）
  - `GovProjectPullAppService`、Refit 响应 DTO、`IGovProjectInitFieldProvider`（弃用或移除占位逻辑）
  - `GovProjectDto` 系列、EF Core 迁移、Blazor 项目列表展示（可选只读列）
- **BasePlatform.PublicApi**（已在独立仓库完成，本 change 仅更新 spec 描述，不在 apply 阶段改代码）
- **数据**：EF 迁移仅新增 `ProAddress`、`ShigongUnitName` 列；不新增 `ProductCode` 列
