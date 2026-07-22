# 实施任务清单

> 所有代码改动在子仓库 `repos/MaterialClient/` 中进行；OpenSpec 工件在主仓库 `openspec/changes/add-recycle-provider-edit/`。
> 实现约定见 `repos/MaterialClient/AGENTS.md`（ReactiveUI、MVVM、ABP 约定）。
> 本变更为纯 UI 接线：后端 `EditCommand`/`EditAsync`/`ProviderEditWindow`/`UpdateProviderAsync` 均已就绪。
> 依赖：归档顺序建议先 `update-provider-create-with-address`（若已实现）再本变更，避免 delta 合并歧义。

## 1. ProviderManagementWindow DataGrid 新增操作列

- [ ] 1.1 修改 `src/MaterialClient.AttendedWeighing/Views/AttendedWeighing/ProviderManagementWindow.axaml`：将第 72 行注释"仅展示列，无操作列"更新为"展示列 + 操作列（编辑按钮）"。
- [ ] 1.2 在 DataGrid.Columns 末尾新增 `DataGridTemplateColumn`（Header="操作"，MinWidth="100"），其 `CellTemplate` 为 `DataTemplate`（`x:DataType="dto:ProviderDto"`），内含一个 `Button`（Content="编辑"，Classes="primary-button"，HorizontalAlignment="Center"）。
- [ ] 1.3 编辑按钮的 `Command` 绑定 `{Binding DataContext.EditCommand, ElementName=Root}`（利用窗口已有的 `x:Name="Root"`），`CommandParameter` 绑定 `{Binding}`（传递当前行 `ProviderDto`）。
- [ ] 1.4 确认 `ProviderManagementWindow.axaml` 顶部已声明 `dto` 命名空间（`xmlns:dto="clr-namespace:MaterialClient.Common.Api.Dtos;assembly=MaterialClient.Common"`，当前第 6 行已存在，无需新增）。

## 2. 构建验证

- [ ] 2.1 在 `repos/MaterialClient/` 根目录执行 `dotnet build MaterialClient.sln -o .build-verify`，确认编译通过（约定：固定使用 `.build-verify` 输出目录避免文件锁）。
- [ ] 2.2 确认无新增 linter 警告/错误；确认 x:DataType 编译时绑定校验通过（`CommandParameter` 类型为 `ProviderDto`，与 `EditCommand` 参数匹配）。

## 3. 手动验证场景（可选，由实施者在 apply 阶段确认）

- [ ] 3.1 打开"数据管理→供应管理" → `ProviderManagementWindow` DataGrid 最右侧出现"操作"列，每行含"编辑"按钮。
- [ ] 3.2 点击某行"编辑" → `ProviderEditWindow` 打开，4 字段（名称/联系人/电话/收货地址）预填该行数据。
- [ ] 3.3 修改字段（含 Address）→ 点击"确定" → 窗口关闭，列表刷新显示新值；重新打开编辑窗口确认 Address 等字段已持久化。
- [ ] 3.4 点击"取消"或关闭编辑窗口 → 列表不刷新，不触发保存。
- [ ] 3.5 空查询结果（无供应商）→ DataGrid 无行，无编辑按钮。
- [ ] 3.6 Recycle 模式启动后，"供应管理"窗口编辑能力与 AttendedWeighing 一致。
