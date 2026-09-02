## 1. Branch & entity

- [x] 1.1 UrbanManagement 切到 Mode B：`dev-urban-entity-semantic`（已在则确认干净工作区）
- [x] 1.2 `GovProject`：`EnableSync` → `IsSyncEnabled`（`bool`，默认 `false`）；移除 `EnableSync`
- [x] 1.3 实体类型归属方法 / 构造路径若写入该字段，改为 `IsSyncEnabled`

## 2. EF migration

- [x] 2.1 新增 migration：`UPDATE` NULL→false（列仍为 `EnableSync`）→ `RenameColumn` 为 `IsSyncEnabled` → non-nullable
- [x] 2.2 本地应用 migration；确认历史 NULL 行为 `false`，列名已改

## 3. DTOs & AppService

- [x] 3.1 `GovProjectDto` / Create / Update：`EnableSync` → `IsSyncEnabled`（DTO 为 non-nullable `bool`；Update 若用可选更新可用 `bool?` 仅 HasValue 时写入）
- [x] 3.2 `SetEnableSyncDto` → `SetIsSyncEnabledDto`；`SetEnableSyncAsync` → `SetIsSyncEnabledAsync`
- [x] 3.3 `FromEntity` / `ToEntity` / Update 映射改用 `IsSyncEnabled`；禁止残留 `EnableSync`
- [x] 3.4 接口 `IGovProjectAppService` 与实现同步改名

## 4. Sync & pull consumers

- [x] 4.1 `GovSyncManager`（及任何 `EnableSync == true` 过滤）改为 `IsSyncEnabled`
- [x] 4.2 BasePlatform pull：insert 默认 `IsSyncEnabled = false`；update 不覆盖该字段
- [x] 4.3 BackgroundWorker / 日志文案中若引用属性名，改为 `IsSyncEnabled`

## 5. Blazor

- [x] 5.1 `ProjectManagement.razor`：开关绑定 `IsSyncEnabled`；调用 `SetIsSyncEnabledAsync`
- [x] 5.2 列表列仍显示「启用同步」文案；确认无 `EnableSync` 绑定残留

## 6. Tests & verify

- [x] 6.1 更新/新增单元或集成测试：过滤、Set API、Pull 不覆盖、默认 false
- [x] 6.2 编译并跑相关测试通过
- [x] 6.3 勾选本 tasks；合入前按 openspec-git-workflow squash 到 `dev-urban-entity-semantic`（用户确认后）
- [x] 6.4 Archive 本 change（用户确认后；默认 sync delta → `openspec/specs/`）
