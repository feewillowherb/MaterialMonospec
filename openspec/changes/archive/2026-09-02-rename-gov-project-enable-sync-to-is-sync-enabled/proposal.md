## Why

`GovProject.EnableSync` 为 `bool?`，命名也不符合布尔属性惯例（`Is*`）。调研 P2 [D17](../../docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md#22-2026-09-02第二批--消歧) 要求属性 **重命名为 `IsSyncEnabled`**，类型收紧为 **non-nullable `bool`**（默认 `false`），并做 EF 列物理 rename，统一政府同步选项目过滤与 Blazor 开关语义。

## What Changes

- `GovProject.EnableSync` → **`IsSyncEnabled`**：`bool?` → non-nullable `bool`，默认 `false`。
- EF migration：列 `EnableSync` **Rename** 为 `IsSyncEnabled`；NULL 回填为 `false` 后加 non-nullable。
- DTO / API：`GovProjectDto`、Create/Update、`SetEnableSyncDto` → `SetIsSyncEnabledDto`（或等价），JSON `isSyncEnabled`；AppService `SetIsSyncEnabledAsync`。
- 同步选项目：`GovSyncManager.GetActiveProjectIdsAsync` 等改为 `p.IsSyncEnabled`。
- Pull 同步：新建项目默认 `IsSyncEnabled = false`；更新路径仍不覆盖该运营字段。
- Blazor `ProjectManagement`：开关绑定 `IsSyncEnabled`；UI 文案「启用同步」可保留。
- Git：**Mode B** — `dev-urban-entity-semantic`（**仅 UrbanManagement**；MaterialClient 无该字段）。

**本 change 不包含**：P3 `GovSyncData` 强类型；AccessCode 改名（INT-005）；`SiteType` / `ProId`（已独立 change）。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `entity-migration`: `GovProject` 同步开关字段为 `IsSyncEnabled` non-nullable `bool`。
- `urban-management-crud`: DTO / SetSync API 使用 `IsSyncEnabled`。
- `blazor-project-management`: 列表开关绑定 `IsSyncEnabled`。
- `gov-project-baseplatform-pull-sync`: 运营字段名改为 `IsSyncEnabled`；Pull 不覆盖。
- `gov-sync-worker`: 活跃项目过滤使用 `IsSyncEnabled`。

## Impact

- **UrbanManagement**：`GovProject`、DTOs、AppService、PullManager、GovSyncManager、BackgroundWorker 日志文案、Blazor、EF migration、Tests。
- **MaterialClient / FdSoft.BasePlatform**：无变更。
- **BREAKING**：GovProject API JSON 字段 `enableSync` → `isSyncEnabled`；set-sync 端点/方法名随 ABP 约定更新。
