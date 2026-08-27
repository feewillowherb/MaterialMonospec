## Context

Epic `epic/xiaoshan-platform-upload` 已归档六条 change。当前实现：

- `SettingsWindow` 仍用 `RegisterNav` + `FindControl` 字典，在 `OnNavigationSelectionChanged` 里遍历 `SettingsSectionsHost.Children` 设 `IsVisible`；ViewModel 已有 `SelectedSettingsSection` 但 AXAML 未绑定。
- `SettingsWindowViewModel` 内嵌 `_preserved*` 字段与 `BuildUrbanConfigJson` / `ApplyUrbanConfigSnapshot`（信封解析），违反「VM 不承担领域映射」的可测性。
- `SaveAsync` 空 `catch`，推送失败路径与关窗语义混杂。
- MC `XiaoshanUploadFieldMappingService` 地磅 `dataSource` 固定常量；UM 为 `modeSettings.DataSource ?? "WEIGHBRIDGE_XIAOSHAN"`。

约束：ReactiveUI 不变；ViewModel → Service；禁止 tuple；不改 UM Write API / migration。

## Goals / Non-Goals

**Goals:**

- 分区切换声明式、无导航控件注册表
- 城管配置信封编解码进 Common Service + 命名 record
- 保存失败可提示；推送前客户端校验至少一模式
- 客户端 Weighbridge `dataSource` 与 UM 一致

**Non-Goals:**

- 抽出跨仓共享 NuGet（MC/UM 信封类型继续双份拷贝，仅对齐映射语义）
- 改 LocalEvent 推送架构、服务端乐观并发、管理端 Razor
- ContentControl 懒加载分区（全量视觉树可接受）
- 在客户端设置 UI 展示 `configVersion` 或静态字段编辑（仍由服务端权威 + preserve）

## Decisions

### D1：分区可见性绑定 `SelectedSettingsSection`

**决策**：`ListBox` 选中后只写 `SelectedSettingsSection`；各分区 `ScrollViewer` 用 `IsVisible` 绑定（converter 或每区 `bool` 计算属性）。删除 `_navigationItems` 与 `ApplySelectedSection` 扫子树。LPR 列可见性仍可留 code-behind。

**备选**：继续 code-behind 扫 Tag — 拒绝（与已归档 design D2 声明式目标冲突）。

**备选**：`ContentControl` + DataTemplate — 本切片不强制，diff 更大。

### D2：表单映射 Service

**决策**：接口与 `record` 放 **Common**（`SettingsWindowViewModel` 不得引用 Urban 工程）。实现优先放 Common（信封已在 `XiaoshanUploadEnvelopes`）：

- `ApplyToForm(...) → XiaoshanUploadSettingsFormState`
- `ToDraft(form, XiaoshanUploadPreservedStatics) → XiaoshanUploadConfigDraft`

`XiaoshanUploadSettingsFormState`、`XiaoshanUploadPreservedStatics` 为命名 `record`。VM 只绑定 form 字段并调 mapper。

**备选**：实现放 Urban + `[ExposeServices]` — 仅当映射必须依赖 Refit；本切片不需要，拒绝以免 UI 无法注入。

### D3：保存错误可见

**决策**：去掉空 `catch`；硬件保存或萧山推送失败用现有消息框/`ILogger`；失败 MUST NOT 发 `DetailCloseRequestedMessage`。萧山推送失败既有「有服务端行则覆盖 / 无行保留草稿」保持不变。

### D4：客户端 v3 预校验

**决策**：mapper 或 push 前调用与 UM `ValidateModes` 等价规则（至少一启用模式）。失败：不发 LocalEvent，提示用户，窗口保持打开。

### D5：dataSource

**决策**：MC `MapForMode` Weighbridge 使用 `modeSettings.DataSource`（非空）否则 `XiaoshanUploadDefaults.WeighbridgeDataSource`。不改 UM。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| AXAML 绑定 converter 漏分区 | 分区 Tag 与 VM 常量同一字符串表 |
| Mapper 与 UM envelope helper 再漂移 | 客户端单测覆盖默认 Weighbridge、空 `{}` |
| 预校验文案与服务端不完全一致 | 只校验「至少一模式」；其余仍由服务端拒绝 |

## Migration Plan

1. Mapper + record，VM 改调用
2. 绑定分区可见性，删导航字典
3. Save 错误提示 + 预校验
4. 对齐 dataSource；编译 Urban/Main

回滚：Epic 分支 revert 本 change 提交。

## Open Questions

无阻塞。预校验提示文案 apply 时与现有 MessageBox 风格对齐即可。
