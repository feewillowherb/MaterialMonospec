# 实施任务清单

> 所有代码改动在子仓库 `repos/MaterialClient/` 中进行；OpenSpec 工件在主仓库 `openspec/changes/update-provider-create-with-address/`。
> 实现约定见 `repos/MaterialClient/AGENTS.md`（Record 替代 Tuple、ReactiveUI、ABP 约定）。

## 1. ViewModel 层：新增专用 Interaction 与请求/结果 record

- [x] 1.1 在 `AttendedWeighingDetailViewModelBase`（`src/MaterialClient.AttendedWeighing/ViewModels/AttendedWeighingDetailViewModelBase.cs`）新增 `public sealed record CreateProviderRequest(string Title, string Message, string InitialName)`。
- [x] 1.2 在 `AttendedWeighingDetailViewModelBase` 新增 `public sealed record CreateProviderResult(string Name, string? Address)`。
- [x] 1.3 在 `AttendedWeighingDetailViewModelBase` 新增 `public Interaction<CreateProviderRequest, CreateProviderResult?> CreateProviderInteraction { get; } = new();`。原有的 `ConfirmTextInteraction` 保留不动（供新增材料流程使用）。

## 2. View 层：新增 `CreateProviderDialog` 对话框

- [x] 2.1 新增 `src/MaterialClient.AttendedWeighing/Views/Dialogs/CreateProviderDialog.axaml`：包含"供应商名称"（必填，预填初始名称）与"收货地址"（可选，Watermark 提示）两个 `TextBox`，以及"取消/确认"按钮；样式（宽度、字号、居中、不可缩放）与 `ConfirmTextDialog` 保持一致。
- [x] 2.2 新增 `src/MaterialClient.AttendedWeighing/Views/Dialogs/CreateProviderDialog.axaml.cs`：构造函数接收 `(string title, string message, string initialName)`；名称输入框打开时自动聚焦并全选；地址输入框初始为空；确认按钮返回 `CreateProviderResult(name, address?.Trim() == "" ? null : address?.Trim())`，取消/ESC 返回 `null`；Enter 键等价确认、ESC 等价取消。
- [x] 2.3 在 `AttendedWeighingDetailView.axaml.cs`（`src/MaterialClient.AttendedWeighing/Views/Controls/AttendedWeighingDetailView.axaml.cs`）的 `WireInteractions` 方法中，新增 `CreateProviderInteraction.RegisterHandler`：构造 `CreateProviderDialog`，`ShowDialog<CreateProviderResult?>(owner)` 返回结果。原有 `ConfirmTextInteraction` 处理器保持不变。

## 3. ViewModel 层：改造 `CreateNewProviderAsync` 透传 Address

- [x] 3.1 修改 `RecycleWeighingDetailViewModel.CreateNewProviderAsync`（`src/MaterialClient.AttendedWeighing/ViewModels/RecycleWeighingDetailViewModel.cs`）：改用 `CreateProviderInteraction.Handle(new CreateProviderRequest(...))`，返回 null 则取消；否则调用 `_providerService.CreateProviderAsync(result.Name, deliveryType, result.Address)`。
- [x] 3.2 在 `RecycleWeighingDetailViewModel.CreateNewProviderAsync` 构造返回的 `ProviderDto` 时，设置 `Address = created.Address`。
- [x] 3.3 对 `SolidWasteWeighingDetailViewModel.CreateNewProviderAsync`（`src/MaterialClient.AttendedWeighing/ViewModels/SolidWasteWeighingDetailViewModel.cs`）做与 3.1、3.2 完全相同的改动。

## 4. 实体注释修正

- [x] 4.1 修改 `Provider.Address` 属性注释（`src/MaterialClient.Common/Entities/Provider.cs` 第 84-90 行）：删除"Recycle 内联新建供应商表单层校验必填"的错误描述，改为说明"`Address` 为本地专用、可选可空，内联新建供应商表单可选录入，缺失时落库为 null"。

## 5. 构建验证

- [x] 5.1 在 `repos/MaterialClient/` 根目录执行 `dotnet build MaterialClient.sln -o .build-verify`，确认编译通过（约定：固定使用 `.build-verify` 输出目录避免文件锁）。
- [x] 5.2 确认无新增 linter 警告/错误；确认未引入 tuple 类型（`CreateProviderResult` 为 record）。

## 6. 手动验证场景（可选，由实施者在 apply 阶段确认）

- [x] 6.1 内联新建供应商：填写名称+地址 → 创建成功，`Provider.Address` 落库为填写值。
- [x] 6.2 内联新建供应商：填写名称、地址留空 → 创建成功，`Provider.Address` 为 null，无必填报错。
- [x] 6.3 内联新建供应商：名称留空 → 阻止创建或 Service 抛 `ArgumentException`。
- [x] 6.4 内联新建供应商：取消/ESC → 不调用 Service，返回 null。
- [x] 6.5 内联新增材料：`ConfirmTextDialog` 仍为单输入框形态，不受本次变更影响。
