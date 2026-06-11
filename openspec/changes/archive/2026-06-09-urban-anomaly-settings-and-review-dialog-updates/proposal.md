## Why

当前 Urban 模式下，异常检测阈值仅能通过配置文件维护，现场无法在系统设置中直观配置和调整；同时称重列表与审批交互信息不足（缺少异常原因、上传时间、审批确认与只读称重日期），导致审核效率低且误操作风险高。需要在不影响非 Urban 模式的前提下，完善设置与审批链路的可见性和可控性。

## What Changes

- 在系统设置中新增 `UrbanAnomalyDetection` 可配置项（`UpperLimit`、`LowerLimit`、`DeviationPercentage`），仅 Urban 模式可见，展示在设置页最下方。
- Urban 称重列表区域新增异常原因展示与上传时间展示，异常原因需与当前异常判定结果一致。
- 审批入口改为仅异常记录可点击，正常记录不可触发审批。
- 审批保存前新增确认框，用户确认后才执行更新。
- `WeighingRecordEditDialog` 新增只读“称重日期”字段，用于审批时校验记录时间上下文。

## Capabilities

### New Capabilities
- `urban-approval-confirmation`: 定义 Urban 审批动作的二次确认交互与触发约束（仅异常可审批）。

### Modified Capabilities
- `settings-ui`: 增加 Urban 异常阈值配置区块、可见性规则（仅 Urban 模式）、页面位置（最下方）。
- `urban-anomaly-detection`: 扩展异常原因可读输出需求，供列表展示使用。
- `urban-weighing-list-presentation`: 增加“异常原因”“上传时间”显示字段，并约束审批按钮启用条件。
- `weighing-record-approval`: 审批对话框增加只读称重日期字段，保存前必须二次确认。

## Impact

- **UI/XAML**：`UrbanAttendedWeighingWindow.axaml`、`WeighingRecordEditDialog.axaml` 及对应样式/模板。
- **ViewModel**：`UrbanAttendedWeighingViewModel`、`WeighingRecordEditDialogViewModel` 的字段、命令启用逻辑与确认流程。
- **设置层**：`SettingsWindow` / `SettingsWindowViewModel`、`SystemSettings`（或等价配置对象）新增 Urban 异常阈值编辑入口与持久化映射。
- **数据模型/DTO**：列表项 DTO 需要补充异常原因、上传时间等展示字段；审批输入输出需包含只读称重日期展示值。
- **行为影响**：审批路径新增一步确认，审批触发条件收紧为“仅异常记录”。
