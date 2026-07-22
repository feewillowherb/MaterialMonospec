## Context

当前 Recycle / SolidWaste 称重详情页"内联新建供应商"通过通用对话框 `ConfirmTextDialog`（单输入框，仅收集供应商名称）实现，交互链路为：

- ViewModel 层：`AttendedWeighingDetailViewModelBase.ConfirmTextInteraction`（`Interaction<ConfirmTextRequest, string?>`），`ConfirmTextRequest` 是三元组 `(Title, Message, InitialValue)`。
- 调用方：`RecycleWeighingDetailViewModel.CreateNewProviderAsync` 与 `SolidWasteWeighingDetailViewModel.CreateNewProviderAsync` 均调用 `ConfirmTextInteraction.Handle(...)`，确认后调用 `_providerService.CreateProviderAsync(name, deliveryType)` —— 省略 address 参数。
- View 层：`AttendedWeighingDetailView.axaml.cs` 注册 `ConfirmTextInteraction` 处理器，弹出 `ConfirmTextDialog`，返回 `string?`（名称或 null）。

关键约束：`ConfirmTextDialog` 同时被"新增供应商"和"新增材料"两个场景复用（见 `RecycleWeighingDetailViewModel.CreateNewMaterialAsync` / `SolidWasteWeighingDetailViewModel.CreateNewMaterialAsync`）。因此**不能直接修改 `ConfirmTextDialog`** 增加地址输入框，否则会污染新增材料流程。

同时，`material-provider-sync` spec 现有一条与实际行为不符的需求（"Recycle 内联新建供应商校验 Address 必填"），需通过本次变更修正为"可选可空"。

`ProviderService.CreateProviderAsync(string providerName, DeliveryType deliveryType, string? address = null)` 的 `address` 参数已是可选，Service 层无需改动；远端 `Address` 始终为本地专用字段，不进入远端契约。

## Goals / Non-Goals

**Goals:**
- 让用户在内联新建供应商时**可选地**录入 `Address`（收货地址），`Address` 不强制必填、允许为空。
- 修正 `material-provider-sync` spec 中"Recycle 内联新建供应商校验 Address 必填"这条与代码现状不符的需求，使其描述"可选可空"。
- 修正 `Provider.Address` 实体注释中"表单层校验必填"的错误描述。
- 保持 `ConfirmTextDialog`（新增材料流程）不受影响。

**Non-Goals:**
- 不修改 `ProviderService.CreateProviderAsync` 签名与实现（已支持可选 address）。
- 不修改远端 `CreateProviderInput`/`UpdateProviderInput`/`MaterialProviderListResultDto` 契约。
- 不修改数据库 schema（`Address` 列已存在且 nullable）。
- 不修改 `ProviderEditWindow`（编辑表单已支持 Address，本次不变更编辑流程）。
- 不为 `Address` 增加任何必填校验、格式校验或 ReactiveUI 验证规则。

## Decisions

### 决策 1：新增专用对话框 `CreateProviderDialog`，不复用 `ConfirmTextDialog`

**选择**：新建 `CreateProviderDialog.axaml` + `CreateProviderDialog.axaml.cs`（位于 `Views/Dialogs/`），包含两个 `TextBox`：供应商名称（必填，沿用原校验）、收货地址（可选）。

**理由**：`ConfirmTextDialog` 被新增材料流程复用，直接扩展会破坏该流程的语义与 UI。新增专用对话框职责单一、改动隔离，符合单一职责原则。

**备选方案（放弃）**：
- 扩展 `ConfirmTextDialog` 增加可选地址输入框 —— 会污染新增材料流程，且 `ConfirmTextRequest` 的三元组结构与"返回单字符串"的交互契约难以承载两字段。
- 在 `SearchableSelectionBox` 弹层内直接内联表单 —— 改动面更大，且与现有"弹独立对话框确认"的交互模式不一致。

### 决策 2：新增 `CreateProviderInteraction` 与 `CreateProviderRequest` record，与 `ConfirmTextInteraction` 并存

**选择**：在 `AttendedWeighingDetailViewModelBase` 中新增：
- `public sealed record CreateProviderRequest(string Title, string Message, string InitialName)`（初始名称；Address 初始为空）。
- `public Interaction<CreateProviderRequest, CreateProviderResult?> CreateProviderInteraction { get; } = new();`
- `public sealed record CreateProviderResult(string Name, string? Address)`（返回名称与地址；null 表示取消）。

供应商新建走 `CreateProviderInteraction`，材料新建继续走 `ConfirmTextInteraction`。

**理由**：
- `CreateProviderResult` 用命名 `record` 承载两字段，遵守"禁止 tuple"约定。
- 保留 `ConfirmTextInteraction` 给材料流程，避免牵连。
- `CreateProviderRequest` 不携带初始 Address（新建场景下地址初始为空，符合预期）。

### 决策 3：View 层注册 `CreateProviderInteraction` 处理器，弹出 `CreateProviderDialog`

**选择**：在 `AttendedWeighingDetailView.axaml.cs` 的 `WireInteractions` 中新增 `CreateProviderInteraction.RegisterHandler`，构造 `CreateProviderDialog` 并以 `ShowDialog<CreateProviderResult?>` 返回结果。原有的 `ConfirmTextInteraction` 处理器保持不变。

**理由**：交互注册集中在 View code-behind，与现有 `ConfirmTextInteraction` 模式一致，便于维护。

### 决策 4：`CreateNewProviderAsync` 改用 `CreateProviderInteraction`，透传 address

**选择**：`RecycleWeighingDetailViewModel.CreateNewProviderAsync` 与 `SolidWasteWeighingDetailViewModel.CreateNewProviderAsync` 改为：
```
var result = await CreateProviderInteraction.Handle(new CreateProviderRequest(...));
if (result == null) return null;
var created = await _providerService.CreateProviderAsync(result.Name, deliveryType, result.Address);
```
返回的 `ProviderDto` 设置 `Address = created.Address`。

**理由**：复用 `ProviderService.CreateProviderAsync` 已有的可选 address 参数与回填逻辑（Service 层在远端创建后、本地 upsert 前回填 address），无需改动 Service 层。

## Risks / Trade-offs

- **[风险] 新增专用对话框与现有 `ConfirmTextDialog` 风格不一致** → Mitigation：`CreateProviderDialog` 复用与 `ConfirmTextDialog` 一致的样式（宽度、字号、按钮、Window 居中、ESC/Enter 键行为），保持视觉一致。
- **[风险] `CreateProviderDialog` 中名称为空时仍允许确认** → Mitigation：沿用 `ProviderService.CreateProviderAsync` 对 `providerName` 的非空校验（抛 `ArgumentException`）；对话框内对名称输入框做基础非空提示（与原"确认新增供应商"语义一致，名称一直是必填）。地址输入框不做任何校验。
- **[权衡] 新增一个 Interaction 类型增加少量样板代码** → 接受：换来对材料流程的零影响和清晰的职责边界，值得。
- **[风险] spec 修正"必填→可选"可能被误读为放宽既有校验** → Mitigation：在 spec delta 中明确写出"`Address` 可选可空，表单不强制必填"，并保留"地址为空时落库为 null"的场景描述。
