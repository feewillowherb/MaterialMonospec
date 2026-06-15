## MODIFIED Requirements

### Requirement: Weighing record list page rendering

`WeighingRecord.razor` SHALL render a paginated table of weighing records, consuming `IUrbanWeighingRecordAppService` via DI injection.

#### Scenario: Initial page load

- **WHEN** the user navigates to `/weighing`
- **THEN** the page SHALL call `IUrbanWeighingRecordAppService.GetListAsync()` with default pagination
- **AND** SHALL render a table with columns: 车牌号, 重量(kg), 称重时间, 项目名, 对接码, 数据质量, 异常原因, 同步状态, 同步时间, 操作

#### Scenario: Pagination

- **WHEN** the user selects a different page size or page number
- **THEN** the page SHALL recalculate `SkipCount` and call `GetListAsync` with updated parameters

#### Scenario: Search by plate number and project name

- **WHEN** the user enters search text in the plate number and/or project name inputs
- **THEN** the page SHALL call `GetListAsync` with the search criteria
- **AND** SHALL reset to page 1

## ADDED Requirements

### Requirement: Weighing record photo view operation

`WeighingRecord.razor` SHALL provide a「查看照片」button in the 操作 column for each record row. See `urban-weighing-photo-view` capability for dialog behavior.

#### Scenario: Photo view button visible on each row

- **WHEN** the weighing record table renders with one or more rows
- **THEN** each row SHALL include a「查看照片」button in the 操作 column

#### Scenario: Photo view loads attachments by record id

- **WHEN** the user clicks「查看照片」
- **THEN** the page SHALL call `GetApprovalAttachmentsAsync` with that row's record `Id`
- **AND** SHALL display Lrp and UrbanPhoto images per `urban-weighing-photo-view` requirements

## REMOVED Requirements

### Requirement: Weighing record approval operation

**Reason**: Approval workflow moved to dedicated `/weighing-approval` page (`independent-approval-page` capability).

**Migration**: Use `WeighingApproval.razor` for record approval; `WeighingRecord.razor` is read-only list plus photo view only.
