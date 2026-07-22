## Context

当前 `ProviderManagementWindow`（供应商管理窗口）是一个只读列表：

- View（`src/MaterialClient.AttendedWeighing/Views/AttendedWeighing/ProviderManagementWindow.axaml`）：DataGrid 第 72 行注释明确"仅展示列，无操作列"，只有 5 个 `DataGridTextColumn`（编号、名称、联系人姓名、联系人电话、收货地址），`IsReadOnly="True"`，没有任何编辑按钮。
- ViewModel（`ProviderManagementViewModel.cs:143-158`）：`EditAsync(ProviderDto provider)` 已标注 `[ReactiveCommand]`，源生成器生成参数化命令 `EditCommand`，逻辑完整：
  1. `GetWindow()` 获取当前窗口
  2. 从 DI 解析 `ProviderEditWindowViewModel`，`Initialize(provider)` 预填数据
  3. `new ProviderEditWindow(dialogVm)` + `ShowDialog<ProviderDto?>` 模态打开
  4. 返回非 null 时 `LoadDataAsync()` 刷新列表
- 但全仓库 axaml 中没有任何控件绑定 `EditCommand`，它是未接线的死命令。

编辑窗口链路已就绪：
- `ProviderEditWindow.axaml`：含名称/联系人/电话/地址 4 字段，绑定 `SaveCommand`/`CancelCommand`。
- `ProviderEditWindowViewModel`：`SaveAsync` 调用 `ProviderService.UpdateProviderAsync(id, name, contactName, contactPhone, address)`，返回更新后的 `ProviderDto`。
- `ProviderService.UpdateProviderAsync`：`[UnitOfWork]`，远端更新（不携带 Address）+ 本地 Address 处理（null 保留旧值、空串归一化为 null、非空更新）。

覆盖范围：Recycle 启动后打开 `AttendedWeighingWindow`（`RecycleStartupService.StartupAsync`），其"数据管理→供应管理"菜单（`AttendedWeighingWindow.axaml.cs:129-135`）打开 `ProviderManagementWindow`。因此管理页改动 Recycle 与 AttendedWeighing 同时生效。

## Goals / Non-Goals

**Goals:**
- 在 `ProviderManagementWindow` 的 DataGrid 新增"操作"列，提供"编辑"按钮，绑定已存在的 `EditCommand`，使用户能编辑供应商（含 Address）。
- 复用既有 `ProviderEditWindow` + `UpdateProviderAsync`，零业务逻辑新增。

**Non-Goals:**
- 不修改 `ProviderManagementViewModel`、`ProviderEditWindow`、`ProviderEditWindowViewModel`、`ProviderService`（均已就绪）。
- 不在称重详情页的 `SearchableSelectionBox` 增加内联编辑入口（本次仅管理页）。
- 不修改远端契约、数据库 schema、ABP 服务注册。
- 不改变 Address 字段的可空性（编辑表单 Address 已可选可空）。

## Decisions

### 决策 1：使用 `DataGridTemplateColumn` 承载编辑按钮

**选择**：新增一个 `DataGridTemplateColumn`（Header="操作"），其 `CellTemplate` 内放一个 `Button`（Content="编辑"）。`Button.Command` 绑定到父级窗口 DataContext 的 `EditCommand`，`Button.CommandParameter` 绑定到当前行数据（`ProviderDto`）。

**理由**：Avalonia DataGrid 的 `DataGridTextColumn` 不支持内嵌按钮；`DataGridTemplateColumn` 是承载任意控件（按钮、链接）的标准方式，与现有项目其他管理窗口（如材料管理）的惯例一致。

### 决策 2：按钮命令绑定方式——`RelativeSource` 向上查找窗口 DataContext

**选择**：

```xml
<DataGridTemplateColumn Header="操作" MinWidth="100">
  <DataGridTemplateColumn.CellTemplate>
    <DataTemplate x:DataType="dto:ProviderDto">
      <Button Content="编辑"
              Classes="primary-button"
              Command="{Binding DataContext.EditCommand, ElementName=Root}"
              CommandParameter="{Binding}"
              HorizontalAlignment="Center" />
    </DataTemplate>
  </DataGridTemplateColumn.CellTemplate>
</DataGridTemplateColumn>
```

利用 `ProviderManagementWindow.axaml` 已有的 `x:Name="Root"`（第 9 行）作为 `ElementName`，通过 `DataContext.EditCommand` 访问窗口级 ViewModel 的命令；`CommandParameter="{Binding}"` 把当前行 `ProviderDto` 传给参数化命令。

**备选方案（放弃）**：
- `RelativeSource AncestorType=Window` —— 可行但 `ElementName=Root` 更显式、更可靠（DataGrid 的 DataContext 继承链在模板内有时不稳定）。
- 在 code-behind 处理按钮点击 —— 违背 MVVM，不采用。

**理由**：`ElementName=Root` 是项目内已验证可用的绑定模式（`ProviderManagementWindow.axaml` 已定义 `x:Name="Root"`，分页等控件也绑定到窗口级属性），一致性好。

### 决策 3：编辑按钮样式复用 `primary-button`

**选择**：编辑按钮使用 `Classes="primary-button"`，与窗口内"查询"、"关闭"等按钮风格一致。

**理由**：保持视觉一致性，无需新增样式。

## Risks / Trade-offs

- **[风险] DataGrid 模板内 DataContext 绑定失效** → Mitigation：使用 `ElementName=Root` 显式定位窗口 DataContext，并为 `DataTemplate` 标注 `x:DataType="dto:ProviderDto"` 让编译时绑定校验 `CommandParameter` 类型；实现后在 apply 阶段手动验证点击按钮能触发 `EditAsync`。
- **[风险] 参数化命令 `EditCommand` 的类型不匹配** → Mitigation：`EditAsync(ProviderDto provider)` 生成的 `EditCommand` 接受 `ProviderDto`，`CommandParameter="{Binding}"` 传递的就是行级 `ProviderDto`，类型匹配；编译时 x:DataType 校验会捕获不一致。
- **[权衡] 仅管理页可编辑，称重详情页选择器仍只能新增不能编辑** → 接受：本次按用户明确选择的管理页方案，范围最小化；如需选择器内联编辑，可后续单独提案。
- **[风险] 与未归档的 `update-provider-create-with-address` 变更 delta 冲突** → Mitigation：两变更都 MODIFIED 同一需求 "Provider 本地 Address 字段"，但归档时 OpenSpec 按顺序应用 delta；本变更仅细化"管理页编辑入口"场景，与 create-with-address 的"可选可空"场景互不重叠。归档顺序建议先 `update-provider-create-with-address` 再本变更（在 tasks.md 中注明依赖）。
