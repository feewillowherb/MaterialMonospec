# Urban Approval Confirmation

## Purpose

Defines the secondary confirmation interaction for Urban weighing record approval, ensuring operators explicitly confirm before persisting edits and preventing accidental submissions.

## Requirements

### Requirement: Urban 审批操作二次确认

系统 SHALL 在 Urban 审批保存前提供二次确认对话框，避免误提交。

#### Scenario: 编辑后确认提交
- **WHEN** 操作员在审批编辑弹窗点击“确定”且输入校验通过
- **THEN** 系统 MUST 弹出确认框提示是否提交本次审批修改
- **AND** 仅当操作员确认后，才调用 `UpdateWeighingRecordAsync`

#### Scenario: 取消确认
- **WHEN** 操作员在确认框点击“取消”
- **THEN** 系统 MUST 不调用 `UpdateWeighingRecordAsync`
- **AND** 原审批编辑弹窗或列表状态 MUST 保持不变
