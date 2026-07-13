## 1. 领域模型与枚举



- [x] 1.1 在 `UrbanManagement.Core` 新增 `ProductCode` 枚举（`Standard = 5000`、`SolidWaste = 5010`、`Urban = 5001`），含 `[Description]` 特性；供同步校验与系统常量使用，不入库

- [x] 1.2 扩展 `GovProject` 实体：新增 `ProAddress?`、`ShigongUnitName?`（不新增 `ProductCode` 属性）

- [x] 1.3 新增 EF Core 迁移，为 `Gov_Project` 表添加 `ProAddress`、`ShigongUnitName` 列（nullable）



## 2. Refit 客户端与拉取 DTO



- [x] 2.1 更新 `IBasePlatformProjectHttpClient` 响应 DTO，对齐 PublicApi `ProjectCatalogItemDto` 全字段（含 `ProductCode`、`ProAddress`、`ShigongUnitName`、`BuildLicenseNo`、`FdBuildLicenseNo`、`AuthEndTime`）

- [x] 2.2 在拉取边界校验 `productCode == (int)ProductCode.Urban`；非 5001 记录警告并跳过（不插入、不更新）



## 3. 拉取同步服务



- [x] 3.1 更新 `GovProjectPullAppService`：新插入记录从 API 映射全部目录字段（`ProName`、`ProAddress`、`ShigongUnitName`、`BuildLicenseNo`、`FdBuildLicenseNo`、`AuthEndTime`）

- [x] 3.2 从拉取路径移除 `IGovProjectInitFieldProvider` 占位初始化；清理 DI 注册与无用实现（或标记 obsolete）

- [x] 3.3 对已存在 `ProId`：同步更新全部目录字段（同上六项）；不更新 `EnableSync`、`AddTime`、软删除状态

- [x] 3.4 拉取结果统计区分 `insertedCount` 与 `updatedCount`（或等价指标）



## 4. CRUD DTO 与应用服务



- [x] 4.1 扩展 `GovProjectDto`：`ProAddress`、`ShigongUnitName` 及 `FromEntity` 映射（不含 `ProductCode`）

- [x] 4.2 `GovProjectUpdateDto` 不修改 `ProAddress`/`ShigongUnitName`（由同步服务维护，手工 CRUD 首版不改）

- [x] 4.3 验证 `GovProjectAppService` 列表/详情返回新字段



## 5. UI（可选）



- [x] 5.1 （可选）Blazor 项目列表增加 `ProAddress`、`ShigongUnitName` 只读列



## 6. 验证



- [x] 6.1 单元/集成测试：`productCode=5001` 时正常插入并持久化全部目录字段

- [x] 6.2 单元/集成测试：新插入记录 `BuildLicenseNo`/`FdBuildLicenseNo`/`AuthEndTime` 来自 API 而非占位常量

- [x] 6.3 单元/集成测试：非 5001 的 `productCode` 跳过插入与更新并记日志

- [x] 6.4 单元/集成测试：已存在 `ProId` 二次拉取时更新 `ProName`、地址、对接码、`AuthEndTime`；`EnableSync` 不变

- [ ] 6.5 手动验证：对接已部署 PublicApi，执行拉取；二次拉取确认已存在记录全部目录字段可更新

