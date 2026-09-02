## Context

- 调研 P2 D17：`EnableSync` → `IsSyncEnabled`，non-nullable `bool`，默认 `false`；DB 列物理 rename。
- 前置：P0–P2（ProId / SiteType）已在 `dev-urban-entity-semantic`。
- 现状：`GovProject.EnableSync` 为 `bool?`；DTO / Blazor / `GovSyncManager` / Pull 默认写入均使用旧名。
- 约束：禁止 tuple；Pull 不得覆盖运营开关；Mode B 仅改 UrbanManagement。

## Goals / Non-Goals

**Goals:**

- 全路径（实体、列、DTO、API、UI、同步过滤）统一为 `IsSyncEnabled`。
- NULL 历史值 → `false`，再 non-nullable。

**Non-Goals:**

- 改变「启用同步」产品文案或开关交互形态。
- MaterialClient / BasePlatform。
- AccessCode、SiteType、GovSyncData 强类型。

## Decisions

### 1. 属性与列同名 rename

- **选择**：CLR `IsSyncEnabled` + 列名 `IsSyncEnabled`（`RenameColumn`）。
- **理由**：D17 要求物理 rename，避免影子列。

### 2. NULL → false

- **选择**：migration `UPDATE ... SET EnableSync = 0 WHERE EnableSync IS NULL`，再 rename + non-nullable。
- **理由**：与「默认关闭同步」一致；NULL 从未表示「开启」。

### 3. API / DTO 命名

- **选择**：
  - `GovProjectDto.IsSyncEnabled`（`bool`）
  - `SetEnableSyncDto` → `SetIsSyncEnabledDto`，属性 `IsSyncEnabled`
  - `SetEnableSyncAsync` → `SetIsSyncEnabledAsync`
- **理由**：与实体一致；ABP 路由随方法名变为 `set-is-sync-enabled`。
- **备选**：保留旧方法名包装 — 拒绝，避免双名。

### 4. UpdateDto

- **选择**：`GovProjectUpdateDto.IsSyncEnabled` 可为 `bool?`（仅当 HasValue 时写入），或移除由专用 toggle API 负责；**优先**专用 `SetIsSyncEnabledAsync`，UpdateDto 若保留则同步改名。
- **理由**：现状已是专用 toggle + UpdateDto 可选字段。

### 5. Pull insert 默认

- **选择**：新建 `GovProject` 时 `IsSyncEnabled = false`（与现 `EnableSync = false` 相同语义）。

## Risks / Trade-offs

- **[Risk] API BREAKING**（JSON / 路由）→ 仅 UrbanManagement 自有 Blazor 消费，同版本部署即可。
- **[Trade-off] ABP 自动路由变更** → 前端改为新方法名。

## Migration Plan

1. 备份 SQLite。
2. NULL→false → RenameColumn → Alter non-nullable。
3. 部署 UM。
4. 回滚：restore backup。

## Open Questions

- 无阻塞项。
