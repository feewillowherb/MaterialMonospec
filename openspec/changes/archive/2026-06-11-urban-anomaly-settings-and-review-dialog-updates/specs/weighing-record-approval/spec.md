## ADDED Requirements

### Requirement: 审批弹窗展示只读称重日期

`WeighingRecordEditDialog` SHALL 新增只读称重日期字段，供审批时核对记录时间。

#### Scenario: 打开弹窗显示称重日期
- **WHEN** 操作员点击异常记录“审批”并打开编辑弹窗
- **THEN** 弹窗 MUST 显示该记录的称重日期字段
- **AND** 称重日期字段 MUST 为只读不可编辑

#### Scenario: 关闭与提交不修改称重日期
- **WHEN** 操作员保存或取消审批
- **THEN** 审批流程 MUST NOT 修改称重日期原始值

### Requirement: 审批前确认交互

审批保存操作 SHALL 在持久化前弹出确认框，确认后才执行更新。

#### Scenario: 确认后执行更新
- **WHEN** 操作员点击“确定”并在确认框选择“确认”
- **THEN** 系统 MUST 执行审批更新流程

#### Scenario: 拒绝确认不更新
- **WHEN** 操作员在确认框选择“取消”
- **THEN** 系统 MUST 中止审批更新流程
- **AND** 记录数据 MUST 保持不变
