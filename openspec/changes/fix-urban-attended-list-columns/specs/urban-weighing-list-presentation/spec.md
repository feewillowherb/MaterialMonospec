## ADDED Requirements

### Requirement: Checkpoint and finished-product dedicated columns align with row template

When the Urban attended list tab is「卡口」or「成品」, the list header and each passage row MUST use the same dedicated column set and bindings. The weighing/mixed column template MUST NOT be used for rows on those tabs.

#### Scenario: Dedicated header and row share columns

- **WHEN** the operator selects「卡口」or「成品」
- **THEN** the header MUST show plate, plate color, vehicle type, in/out, site, capture time, and upload time
- **AND** each row MUST bind `DisplayPlate`, `PlateColor`, `VehicleType`, `InOutText`, `SiteTypeText`, `SortTime` (as capture time), and `UploadTime` in that order
- **AND** MUST NOT bind `KindLabel`, `WeightText`, or `StatusText` into those dedicated columns

#### Scenario: Site shows site type not capture time

- **WHEN** a checkpoint or finished-product row is rendered on its dedicated tab
- **THEN** the site column MUST display `SiteTypeText`（工地 / 消纳）
- **AND** MUST NOT display `SortTime` in the site column
- **AND** the capture-time column MUST display `SortTime` formatted as `yyyy-MM-dd HH:mm`

### Requirement: Weighing in/out from extension when present

Weighing-kind list rows SHALL display enter/exit text when `UrbanWeighingExtension` stores a non-null `UrbanInOutType` for that weighing record. When absent, the in/out cell MUST show「—」.

#### Scenario: Extension has in/out

- **WHEN** a weighing-kind row is prepared and the extension has `UrbanInOutType` set
- **THEN** `InOutText` MUST be「进」or「出」according to that value
- **AND**「正常」and「异常」tabs MUST show that text in the in/out column

#### Scenario: Extension missing in/out

- **WHEN** a weighing-kind row has no stored `UrbanInOutType`
- **THEN** `InOutText` MUST be「—」

## MODIFIED Requirements

### Requirement: 列表展示上传时间

Urban 左侧列表（「全部记录」「正常」「异常」「卡口」「成品」）SHALL 显示上传时间列，用于显示记录上云时间。地磅行使用既有 `UploadTime` 投影；进出行使用 passage 同步成功时写入的上传时间。无值显示「—」。

#### Scenario: 有上传时间

- **WHEN** 列表项 `UploadTime` 有值
- **THEN** 行模板 MUST 显示上传时间
- **AND** 时间格式 MUST 为 `yyyy-MM-dd HH:mm`（与抓拍时间列一致）

#### Scenario: 无上传时间

- **WHEN** 列表项 `UploadTime` 为空
- **THEN** 行模板 MUST 显示「—」

#### Scenario: Passage upload time after sync

- **WHEN** a passage record is marked synced successfully
- **THEN** the passage entity MUST record upload time via a type-owned method
- **AND** subsequent list projection MUST map that value to `UploadTime`

### Requirement: All-records mixed table with large photo only

When the Urban attended list tab is「全部记录」, `ListItems` SHALL contain a time-ordered mix of weighing and passage rows. Each row MUST carry a kind: weighing, checkpoint, or finished product. Mixed columns MUST stay visible: type, plate, weight, in/out, capture time（抓拍时间）, upload time（上传时间）, status, actions; missing values MUST show「—」rather than hiding columns. The right-side photo MUST show only the large image (empty if none). Plate color, vehicle type, and site type MUST NOT appear as mixed-table columns. Checkpoint and finished-product rows MUST NOT use `IsAnomaly` and MUST NOT show an approve button in this change.

#### Scenario: Mixed page is time-ordered

- **WHEN** the operator views「全部记录」with both weighing and passage data in the filter window
- **THEN** rows MUST interleave by record time descending (weighing time vs `CapturedAt`)
- **AND** pagination MUST apply after merging the two sources under the same filters (not one page of weighing stacked on one page of passage)

#### Scenario: Passage cells in mixed columns

- **WHEN** a mixed-table row is a passage record
- **THEN** type MUST be「卡口」or「成品」
- **AND** weight and status MUST display「—」
- **AND** in/out MUST display enter/exit from `UrbanInOutType`
- **AND** the action cell MUST NOT run weighing approval

#### Scenario: Weighing cells in mixed columns

- **WHEN** a mixed-table row is a weighing record
- **THEN** type MUST be「地磅」
- **AND** weight, status, and approve MUST follow existing weighing rules for that row
- **AND** in/out MUST show「进」/「出」when the extension stores `UrbanInOutType`, otherwise「—」

#### Scenario: Normal and anomaly tabs stay weighing-only

- **WHEN** the operator selects「正常」or「异常」
- **THEN** the list MUST contain only weighing rows filtered by `IsAnomaly`
- **AND** MUST NOT include passage rows
- **AND** the time column header MUST read「抓拍时间」
- **AND** the upload-time column MUST be visible

#### Scenario: Sidebar photo is large only

- **WHEN** a mixed-table or weighing-tab row is selected
- **THEN** the right-side photo MUST bind the large capture/LPR image only
- **AND** MUST NOT display the small plate-crop image in that pane
