## Why

当前 `material-provider-sync` spec 的 "Recycle 内联新建供应商校验 Address 必填" 场景（`openspec/specs/material-provider-sync/spec.md` 第 170-173 行）要求在内联新建供应商时把 `Address` 强制设为必填，但实际代码从未实现该校验（`Provider.Address` 实体注释也遗留了"表单层校验必填"的错误描述），而内联新增表单 `ConfirmTextDialog` 只收集供应商名称，根本不提供 `Address` 输入入口。业务上 `Address` 作为本地专用收货地址，不应在新建阶段就阻断用户；用户希望新增供应商时**可选地**录入 `Address`（可空），同时让实体注释与 spec 描述回归与代码一致。

## What Changes

- **MODIFIED**：将 `material-provider-sync` spec 中"Recycle 内联新建供应商校验 Address 必填"场景改为"`Address` 可选可空"，使 spec 与实际行为一致。
- **MODIFIED**：扩展 Recycle / SolidWaste 称重详情中"内联新建供应商"的表单，从单输入框（仅供应商名称）升级为可同时录入供应商名称与收货地址（`Address`）的表单。
- `Address` 在新增表单中**不是必填**，允许为空；用户不填时与现状一致（落库为 null）。
- 修正 `Provider.Address` 实体注释，删除"表单层校验必填"的错误描述，改为"可选可空"。
- 复用已有的 `ProviderService.CreateProviderAsync(name, deliveryType, address)` 签名（address 已是可选参数），无需修改 Service 层契约与远端契约（`Address` 始终为本地专用字段）。
- 同步调用方（`RecycleWeighingDetailViewModel`、`SolidWasteWeighingDetailViewModel`）在 `CreateNewProviderAsync` 中将用户填写的 `address` 透传给 Service。

## Capabilities

### New Capabilities
<!-- 本次不引入新能力，仅修改现有能力的需求。 -->

### Modified Capabilities
- `material-provider-sync`: 将 "Recycle 内联新建供应商校验 Address 必填" 场景修改为 "`Address` 可选可空，新增表单可选录入"，并扩展内联新建表单支持录入 `Address`。

## Impact

- **受影响代码（子仓库 `repos/MaterialClient/`）**：
  - View：`src/MaterialClient.AttendedWeighing/Views/Dialogs/ConfirmTextDialog.axaml`（扩展为多字段表单，或新增专用对话框）。
  - View code-behind：`src/MaterialClient.AttendedWeighing/Views/Controls/AttendedWeighingDetailView.axaml.cs`（交互处理器适配新表单结构）。
  - ViewModel：`src/MaterialClient.AttendedWeighing/ViewModels/AttendedWeighingDetailViewModelBase.cs`（`ConfirmTextRequest` 扩展或新增请求类型承载 `Address`）。
  - ViewModel：`src/MaterialClient.AttendedWeighing/ViewModels/RecycleWeighingDetailViewModel.cs`、`SolidWasteWeighingDetailViewModel.cs`（`CreateNewProviderAsync` 透传 `address` 到 `ProviderService.CreateProviderAsync`）。
  - 实体注释：`src/MaterialClient.Common/Entities/Provider.cs`（修正 `Address` 属性注释）。
- **不受影响**：
  - `ProviderService.CreateProviderAsync` 签名与实现（`address` 已是可选参数，Service 层已支持回填）。
  - 远端 `CreateProviderInput`/`UpdateProviderInput`/`MaterialProviderListResultDto` 契约（`Address` 为本地专用，不进入远端）。
  - 数据库 schema（`Address` 列已存在且为 nullable）。
  - `ProviderEditWindow`（编辑表单已支持 `Address`，本次不变更编辑流程）。
- **API / 依赖**：无外部 API 变更，无新增依赖。
- **风险**：`ConfirmTextDialog` 为通用对话框，被多处复用；扩展时须保持对现有调用方（仅传名称场景）的向后兼容，避免破坏其它使用点。
