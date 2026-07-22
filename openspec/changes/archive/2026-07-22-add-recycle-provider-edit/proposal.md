## Why

当前 Recycle（以及复用同一套窗口的 AttendedWeighing）模式下，用户只能"新增"供应商，**无法编辑供应商**。经过代码核查发现：编辑功能的后端与窗口代码已完整存在——`ProviderEditWindow`（含名称/联系人/电话/地址 4 字段表单）、`ProviderEditWindowViewModel`（调用 `ProviderService.UpdateProviderAsync`）、`ProviderManagementViewModel.EditAsync(ProviderDto)`（带 `[ReactiveCommand]`，逻辑完整：打开编辑窗口、保存后刷新列表）——但 `ProviderManagementWindow` 的 DataGrid 是只读列表（注释明确写"仅展示列，无操作列"），**没有任何控件绑定已生成的 `EditCommand`**，导致编辑入口在 UI 层缺失。用户需要能修改供应商信息（尤其是本次新增的可选 Address 字段录入错误后需修正）。

## What Changes

- **MODIFIED**：在 `ProviderManagementWindow.axaml` 的 DataGrid 新增"操作"列，内含"编辑"按钮，绑定已存在的 `ProviderManagementViewModel.EditCommand`（参数为当前行 `ProviderDto`）。
- 启用既有的编辑链路：点击"编辑" → 打开 `ProviderEditWindow`（预填当前行数据） → 用户修改名称/联系人/电话/收货地址 → 确认后调用 `ProviderService.UpdateProviderAsync`（已支持 Address 本地专用处理）→ 保存成功后刷新管理列表。
- `Address` 在编辑表单中保持现状（已存在、非必填、可空），无需修改 `ProviderEditWindow` 与 `ProviderEditWindowViewModel`。
- 不新增任何代码逻辑（`EditCommand`/`EditAsync`/`ProviderEditWindow`/`UpdateProviderAsync` 均已就绪），本次变更为**纯 UI 接线**：把未绑定的命令接到按钮上。

## Capabilities

### New Capabilities
<!-- 本次不引入新能力，仅修改现有能力的需求。 -->

### Modified Capabilities
- `material-provider-sync`: 将 "Provider 管理页展示与编辑 Address" 场景细化为"管理页提供可操作的编辑入口（DataGrid 操作列 + 编辑按钮）"，明确用户可在管理页直接编辑供应商（含 Address）。

## Impact

- **受影响代码（子仓库 `repos/MaterialClient/`）**：
  - View：`src/MaterialClient.AttendedWeighing/Views/AttendedWeighing/ProviderManagementWindow.axaml`（DataGrid 新增"操作"列 + 编辑按钮，绑定 `EditCommand`；更新第 72 行注释）。
- **不受影响**：
  - `ProviderManagementViewModel.cs`（`EditAsync` + `EditCommand` 已存在，无需改动）。
  - `ProviderEditWindow.axaml(.cs)`、`ProviderEditWindowViewModel.cs`（编辑表单已完整）。
  - `ProviderService.UpdateProviderAsync`（已支持 Address 本地专用处理）。
  - `SearchableSelectionBox` 与称重详情页选择器（本次不改动内联编辑入口，仅管理页）。
  - 数据库 schema、远端契约。
- **覆盖范围说明**：Recycle 启动后实际打开 `AttendedWeighingWindow`（`RecycleStartupService.StartupAsync`），其"数据管理→供应管理"菜单打开 `ProviderManagementWindow`。因此本次对管理页的改动 Recycle 与 AttendedWeighing 同时受益。
- **API / 依赖**：无新增依赖，无 API 变更。
- **风险**：`EditCommand` 是 `ReactiveCommand<ProviderDto, IRoutableCommand>` 参数化命令，DataGrid 操作列按钮需正确传递当前行 `ProviderDto` 作为命令参数；绑定方式错误会导致命令不触发。需验证 Avalonia DataGrid `DataGridTemplateColumn` 中按钮 `Command="{Binding DataContext.EditCommand, RelativeSource...}"` + `CommandParameter="{Binding}"` 的写法。
