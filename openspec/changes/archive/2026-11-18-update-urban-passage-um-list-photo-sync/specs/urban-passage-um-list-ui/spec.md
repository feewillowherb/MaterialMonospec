## ADDED Requirements

### Requirement: Passage list shows sync status badge and sync time

UrbanManagement Blazor pages「卡口进出」and「成品进出」SHALL display government sync status with the same badge styling and labels as the weighing list page, and SHALL display sync time.

#### Scenario: Sync columns on checkpoint list

- **WHEN** the operator opens `/checkpoint-passage` with one or more rows
- **THEN** each row MUST show a sync-status badge using labels 待同步 / 同步成功 / 同步失败 according to `SyncType`
- **AND** MUST show a 同步时间 cell formatted as `yyyy-MM-dd HH:mm:ss` when `SyncTime` is present, otherwise `-`

#### Scenario: Sync columns on finished-product list

- **WHEN** the operator opens `/finished-product-passage` with one or more rows
- **THEN** sync status badge and sync time MUST follow the same rules as the checkpoint list

### Requirement: Passage list view-photo action

Both passage list pages SHALL provide a per-row「查看照片」action that opens a modal dialog showing the row large image when available.

#### Scenario: Open photo when image present

- **WHEN** the operator clicks「查看照片」on a row whose list DTO has non-empty `LargeImageBase64`
- **THEN** a modal MUST open showing that image
- **AND** the dialog title MUST include plate display and capture time
- **AND** closing the dialog MUST return to the list without navigation

#### Scenario: Open photo when image missing

- **WHEN** the operator clicks「查看照片」on a row with null or empty `LargeImageBase64`
- **THEN** the modal MUST still open
- **AND** MUST show an empty-state message (no silent no-op)

#### Scenario: Pages do not use weighing photo API

- **WHEN** passage photo dialog loads content
- **THEN** it MUST NOT call weighing-record AppService photo APIs
- **AND** MUST use passage list DTO image data (or a future passage-scoped API if introduced in the same change)

### Requirement: Passage list actions coexist with reset sync

「查看照片」MUST appear in the actions column alongside the existing「重置同步」control when reset is allowed. Reset behavior MUST remain unchanged by this capability.

#### Scenario: Both actions visible when reset allowed

- **WHEN** a passage row has `SyncType` Success or Failed (TEMP reset eligibility)
- **THEN** the actions cell MUST show both「查看照片」and「重置同步」
