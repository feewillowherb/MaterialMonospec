# Independent Approval Page

## Purpose

Dedicated approval page for anomalous weighing records, separated from the general weighing record management page, with anomaly filter controls and full approval workflow.
## Requirements
### Requirement: Independent approval page route

The system SHALL provide a dedicated approval page at route `/weighing-approval` accessible from the sidebar navigation.

#### Scenario: Page accessible from sidebar

- **WHEN** the administrator clicks the "异常审批" navigation link in the sidebar
- **THEN** the system SHALL navigate to `/weighing-approval`
- **AND** a new tab labeled "异常审批" SHALL appear in the tab bar

#### Scenario: Direct URL access

- **WHEN** the administrator navigates directly to `/weighing-approval`
- **THEN** the approval page SHALL load without error
- **AND** the sidebar SHALL highlight the "异常审批" navigation item

### Requirement: Approval page default anomaly filter

The approval page SHALL default to showing only anomalous weighing records (`IsAnomaly == true`).

#### Scenario: Page loads with anomaly filter active

- **WHEN** the approval page initializes
- **THEN** the system SHALL query `GetListAsync` with `IsAnomaly = true`
- **AND** the filter dropdown SHALL display "仅异常" as the selected option
- **AND** only records where `IsAnomaly == true` SHALL be displayed

#### Scenario: Non-anomalous records hidden by default

- **WHEN** the approval page loads and no anomalous records exist
- **THEN** the table SHALL show the empty state message "暂无数据"

### Requirement: Approval page anomaly filter toggle

The approval page SHALL provide a filter toggle to switch between anomaly-only, normal-only, and all-records views.

#### Scenario: Switch to all records

- **WHEN** the administrator selects "全部记录" from the filter dropdown
- **THEN** the system SHALL re-query `GetListAsync` without an `IsAnomaly` filter
- **AND** both anomalous and non-anomalous records SHALL be displayed

#### Scenario: Switch to normal records only

- **WHEN** the administrator selects "仅正常" from the filter dropdown
- **THEN** the system SHALL re-query `GetListAsync` with `IsAnomaly = false`
- **AND** only records where `IsAnomaly == false` SHALL be displayed

#### Scenario: Switch back to anomaly only

- **WHEN** the administrator selects "仅异常" from the filter dropdown
- **THEN** the system SHALL re-query `GetListAsync` with `IsAnomaly = true`

#### Scenario: Filter selection persists during search

- **WHEN** the administrator changes the anomaly filter and then performs a plate number or project search
- **THEN** the anomaly filter SHALL remain active alongside the search filters

### Requirement: Approval page retains all search filters

The approval page SHALL provide the same search controls as WeighingRecord.razor: plate number text input and project name searchable select.

#### Scenario: Plate number search on approval page

- **WHEN** the administrator enters a plate number and clicks "搜索"
- **THEN** the system SHALL query with both the plate number filter and the current anomaly filter
- **AND** the current page SHALL reset to 1

#### Scenario: Project name search on approval page

- **WHEN** the administrator selects a project from the searchable select
- **THEN** the system SHALL query with both the project name filter and the current anomaly filter
- **AND** the current page SHALL reset to 1

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

### Requirement: Approval page pagination

The approval page SHALL use the same pagination controls and logic as WeighingRecord.razor.

#### Scenario: Page navigation

- **WHEN** the administrator clicks a page button
- **THEN** the system SHALL query with the selected page number and the current anomaly filter
- **AND** the total count SHALL reflect the filtered result set

### Requirement: Approval page standalone photo view

`WeighingApproval.razor` SHALL provide「查看照片」as a standalone row action independent of the approval modal. See `urban-weighing-photo-view` capability.

#### Scenario: View photos without opening approval modal

- **WHEN** the administrator clicks「查看照片」on any row
- **THEN** a read-only photo dialog SHALL open without requiring approval permissions on form fields
- **AND** images SHALL be loaded via `GetApprovalAttachmentsAsync`

