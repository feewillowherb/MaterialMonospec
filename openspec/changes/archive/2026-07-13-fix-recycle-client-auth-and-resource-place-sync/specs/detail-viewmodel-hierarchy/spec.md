## ADDED Requirements

### Requirement: Recycle 独立客户端挂载 Attended 称重 UI
Recycle 独立客户端（`MaterialClient.Recycle`）SHALL 在启动成功后显示与 SolidWaste 等价的 Attended 称重主界面，而非占位窗口。

#### Scenario: 主界面为 AttendedWeighingWindow
- **WHEN** Recycle 应用完成授权与登录
- **THEN** 主窗口 SHALL 为 `AttendedWeighingWindow`（或 UI 共享层等价类型）
- **AND** SHALL NOT 以仅显示「称重数据上报管线已就绪」的占位 UI 作为生产主界面

#### Scenario: Recycle 模式创建称重记录
- **WHEN** 用户在 Recycle 客户端完成一次称重并保存
- **THEN** 创建的 `WeighingRecord.WeighingMode` SHALL 为 `WeighingMode.Recycle`
- **AND** 该记录 SHALL 可被 `RecycleDataSyncService` 扫描上报

#### Scenario: Recycle 详情弹窗复用 SolidWaste ViewModel
- **WHEN** 用户在 Recycle 客户端打开称重详情
- **THEN** SHALL 使用 `SolidWasteWeighingDetailViewModel`（与 `WeighingMode.Recycle` 分支一致）
- **AND** SHALL NOT 使用 `StandardWeighingDetailViewModel`

### Requirement: Auth 与 Login 窗口 UI 共享
Auth 与 Login 窗口及 ViewModel SHALL 位于 Recycle 可引用的程序集（`MaterialClient.UI` 或 Recycle 项目内），使独立 Recycle exe 无需引用 MaterialClient 主程序项目。

#### Scenario: Recycle 项目可解析 Auth 窗口
- **WHEN** `MaterialClient.Recycle` 编译
- **THEN** SHALL 可 DI 解析授权码窗口与 ViewModel
- **AND** SHALL NOT 项目引用 `MaterialClient` 主程序 csproj

#### Scenario: 主程序 5000/5010 仍可启动
- **WHEN** UI 共享迁移完成后 MaterialClient 主程序启动
- **THEN** 5000/5010 授权与登录流程 SHALL 保持可用
