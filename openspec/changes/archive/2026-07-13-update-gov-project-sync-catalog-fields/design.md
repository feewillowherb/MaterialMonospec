## Context

BasePlatform.PublicApi `GET /Api/ProjectCatalog/ListProjects` 已更新（独立仓库 `FdSoft.BasePlatform.PublicApi`）：

- 仅返回 `JCProductAuthority.ProductCode = 5001`（城管 Urban）且 `MachineCode` 非空的项目
- 每条记录包含：`proId`、`proName`、`productCode`、`proAddress`、`shigongUnitName`、`buildLicenseNo`、`fdBuildLicenseNo`、`authEndTime`

UrbanManagement 首版拉取同步（`sync-gov-project-from-baseplatform-publicapi`）仅持久化 `ProId`/`ProName`，并通过 `IGovProjectInitFieldProvider` 以配置常量占位 `BuildLicenseNo`/`FdBuildLicenseNo`。`GovProject` 实体当前无 `ProAddress`、`ShigongUnitName`。

本 change 仅在 `repos/UrbanManagement` 实现对接；PublicApi 代码已就绪，OpenSpec 仅同步需求描述。

UrbanManagement 作为城管固废专用系统，其 `GovProject` 表在可预见范围内仅服务 Urban（5001）产品；`productCode` 对所有行相同，**不必在实体层重复存储**。

## Goals / Non-Goals

**Goals:**

- 定义 `ProductCode` 枚举供同步边界校验与代码层常量（与 MaterialClient `WeighingMode` 数值对齐）
- `GovProject` 扩展 `ProAddress`、`ShigongUnitName` 并持久化
- 拉取同步从 API 映射全部目录字段；新记录插入；已存在记录 **upsert 更新全部目录字段**
- Refit 客户端 DTO、应用服务、EF 迁移、GovProject CRUD DTO 与 spec 一致
- 非 `5001` 的 `productCode` 在同步边界跳过并记日志

**Non-Goals:**

- 不修改 BasePlatform.PublicApi 代码（本 monorepo apply 范围外）
- 不在 `GovProject` 表持久化 `ProductCode`（系统上下文隐含 Urban）
- 不通过同步覆盖本地运营字段（`EnableSync` 等）
- 不实现远端项目删除的回写（软删除状态不由同步驱动）
- 不扩展 PublicApi 返回其他 ProductCode（5000/5010）的过滤
- 不在本 change 强制改造 Blazor UI 全部列展示（可选只读列，非阻塞）

## Decisions

### Decision 1: `ProductCode` 枚举仅用于代码层，不入库

**选择**：在 `UrbanManagement.Core` 新增：

```csharp
public enum ProductCode
{
    [Description("物料验收系统客户端软件")]
    Standard = 5000,

    [Description("城管固废称重验收系统客户端软件")]
    SolidWaste = 5010,

    [Description("城管固废称重验收系统客户端软件")]
    Urban = 5001
}
```

`GovProject` **不包含** `ProductCode` 属性。系统默认产品为 `ProductCode.Urban`，可在配置或常量类中暴露（如 `UrbanManagementConsts.TargetProductCode`）。

**理由**：YAGNI；UrbanManagement bounded context 即 Urban 产品；减少迁移与 CRUD 复杂度。

### Decision 2: 同步边界校验 `productCode`，不映射入库

**选择**：在 `GovProjectPullAppService` 校验 Refit 响应 `int productCode`：

- `productCode == (int)ProductCode.Urban`（5001）→ 继续插入/更新流程
- 其他值 → 记录警告日志并**跳过该条**（不插入、不更新）

### Decision 3: 废弃 `IGovProjectInitFieldProvider` 占位初始化

**选择**：插入与更新均从 `ProjectCatalogItemDto` 赋值目录字段；`IGovProjectInitFieldProvider` 从拉取路径移除。

### Decision 4: 实体与 DTO 扩展字段

**`GovProject` 新增**（持久化）：

| 属性 | 类型 | 来源 |
|------|------|------|
| `ProAddress` | `string?` | API `proAddress` |
| `ShigongUnitName` | `string?` | API `shigongUnitName` |

**DTO**：`GovProjectDto`、`GovProjectCreateDto`、`GovProjectUpdateDto` 扩展 `ProAddress`、`ShigongUnitName`。

### Decision 5: 已存在记录 upsert 更新全部目录字段

**选择**：`GovProjectPullAppService` 对本地已存在 `ProId` 的记录，从 API **更新全部目录字段**：

| 同步更新 | 来源 |
|----------|------|
| `ProName` | `proName` |
| `ProAddress` | `proAddress` |
| `ShigongUnitName` | `shigongUnitName` |
| `BuildLicenseNo` | `buildLicenseNo` |
| `FdBuildLicenseNo` | `fdBuildLicenseNo` |
| `AuthEndTime` | `authEndTime` |

**不通过同步覆盖**（本地运营/元数据）：`Id`、`AddTime`、`EnableSync`、`IsDeleted`、`DeletionTime`。

**实现**：拉取后分 `toInsert` 与 `toUpdate`；`toUpdate` 批量更新上述六字段，使用 `[UnitOfWork]`。

### Decision 6: EF 迁移

仅新增 `ProAddress`（nvarchar, nullable）、`ShigongUnitName`（nvarchar, nullable）。不新增 `ProductCode` 列。

### Decision 7: Refit 响应 DTO 对齐 PublicApi

UrbanManagement 侧 DTO 字段与 PublicApi JSON camelCase 对齐：`ProId`, `ProName`, `ProductCode`, `ProAddress`, `ShigongUnitName`, `BuildLicenseNo`, `FdBuildLicenseNo`, `AuthEndTime`。`ProductCode` 仅用于校验，不写入 `GovProject`。

## Risks / Trade-offs

- **[同步覆盖本地手工修改的对接码/名称]** → 目录 API 为权威源；运营手工改动的 `ProName`/对接码会在下次同步被覆盖
- **[API 返回非 5001]** → 跳过插入与更新并记日志
- **[IGovProjectInitFieldProvider 移除]** → 确认无其他调用方；删除或 obsolete 并更新 DI 注册

## Migration Plan

1. 合并 UrbanManagement 代码 + 执行 EF 迁移（仅 `ProAddress`、`ShigongUnitName`）
2. 确认 `BasePlatformSync` 指向已部署的新版 PublicApi
3. 触发一次拉取：新插入记录字段完整
4. 验证二次拉取：已存在记录全部目录字段随远端变更而更新；`EnableSync` 不变
5. 回滚：还原迁移（或保留列不用）、关闭 `BasePlatformSync:Enabled`

## Open Questions

- Blazor 项目列表是否在本 change 展示 `ProAddress`/`ShigongUnitName` 列？（建议 tasks 中列为可选）
