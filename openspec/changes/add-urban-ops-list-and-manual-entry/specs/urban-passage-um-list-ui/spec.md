## ADDED Requirements

### Requirement: Passage list shows 施工单位 and 项目 as first two columns

UrbanManagement Blazor pages「卡口进出」and「成品进出」SHALL show **施工单位** as the first column and **项目** as the second column, ahead of plate and other existing columns. **施工单位** SHALL resolve from `GovProject.ShigongUnitName` for the row `ProId` (display `-` when missing). **项目** SHALL display the passage row `ProName` (display `-` when missing).

#### Scenario: Checkpoint column order

- **WHEN** the operator opens `/checkpoint-passage`
- **THEN** the table header SHALL start with 施工单位, then 项目, then the remaining columns
- **AND** each data row SHALL show those two values in the same order

#### Scenario: Finished-product column order

- **WHEN** the operator opens `/finished-product-passage`
- **THEN** the table header and cells SHALL use the same first-two-column rules as the checkpoint list

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

Both passage list pages SHALL provide a per-row「查看照片」action that opens a modal dialog. The dialog SHALL participate in `urban-multi-image-lightbox` (multi-image + left-click enlarge). When only the large capture image is available, it SHALL appear as a one-image set.

#### Scenario: Open photo when image present

- **WHEN** the operator clicks「查看照片」on a row with available image data
- **THEN** a modal MUST open showing that image set
- **AND** left-click enlarge MUST be available per `urban-multi-image-lightbox`

#### Scenario: Open photo when image missing

- **WHEN** the operator clicks「查看照片」on a row with no image
- **THEN** the modal MUST still open with an empty-state message

#### Scenario: Pages do not use weighing photo API for passage rows

- **WHEN** passage photo dialog loads content
- **THEN** it MUST NOT call weighing-record AppService photo APIs for passage entities
