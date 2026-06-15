## MODIFIED Requirements

### Requirement: Approval page table columns

The approval page table SHALL include weighing record columns plus an 操作 column with row actions.

#### Scenario: Table column layout

- **WHEN** the approval page renders the table
- **THEN** columns SHALL include: 车牌号, 重量(kg), 称重时间, 项目名, 对接码, 数据质量, 同步状态, 同步时间, 操作
- **AND** the 操作 column SHALL contain「查看照片」on every row
- **AND** SHALL contain「审批」for anomalous records
- **AND** MAY contain「修改历史」per existing behavior

#### Scenario: Anomaly and sync badges

- **WHEN** the approval page renders record rows
- **THEN** the 数据质量 column SHALL display anomaly badges (异常/正常) matching the existing `GetAnomalyBadgeClass`/`GetAnomalyBadgeText` logic
- **AND** the 同步状态 column SHALL display sync badges (待同步/同步成功/同步失败) matching the existing `GetSyncTypeBadgeClass`/`GetSyncTypeBadgeText` logic

### Requirement: Approval page approval modal

The approval page SHALL include the complete approval modal with LPR/Urban photo preview, plate number and weight editing, validation, and submission.

#### Scenario: Open approval modal from approval page

- **WHEN** the administrator clicks「审批」on an anomalous record row
- **THEN** the approval modal SHALL open with the record's current `PlateNumber` and `TotalWeight`
- **AND** the system SHALL load attachment images via `GetApprovalAttachmentsAsync`
- **AND** Lrp and UrbanPhoto previews SHALL be displayed if available, classified by `AttachType` enum (5 / 6)

#### Scenario: Submit approval from approval page

- **WHEN** the administrator edits fields and clicks「提交审批」
- **THEN** the system SHALL call `ApproveAsync` with the updated values
- **AND** on success, the modal SHALL close and the list SHALL refresh
- **AND** the anomaly filter SHALL remain active after refresh

#### Scenario: Cancel approval from approval page

- **WHEN** the administrator clicks「取消」or closes the modal
- **THEN** no changes SHALL be persisted
- **AND** the list SHALL remain unchanged

#### Scenario: Approval validation on approval page

- **WHEN** the administrator submits with an empty plate number or non-positive weight
- **THEN** the system SHALL display field-level validation errors
- **AND** `ApproveAsync` SHALL NOT be called

## ADDED Requirements

### Requirement: Approval page standalone photo view

`WeighingApproval.razor` SHALL provide「查看照片」as a standalone row action independent of the approval modal. See `urban-weighing-photo-view` capability.

#### Scenario: View photos without opening approval modal

- **WHEN** the administrator clicks「查看照片」on any row
- **THEN** a read-only photo dialog SHALL open without requiring approval permissions on form fields
- **AND** images SHALL be loaded via `GetApprovalAttachmentsAsync`
