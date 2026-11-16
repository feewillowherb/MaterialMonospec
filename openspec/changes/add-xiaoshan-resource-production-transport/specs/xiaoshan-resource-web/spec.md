## MODIFIED Requirements

### Requirement: Authenticated shell shows only the three pictured surfaces

After login, XiaoShanResource SHALL serve a Vue 3 and Element Plus shell. The header title SHALL be 「萧山资源化利用网页端」 and SHALL show the session user name. The sidebar SHALL contain 「车辆管理」「合同管理」「生产管理」「运输清单」 and SHALL NOT contain 仪表盘、消纳场地、 or 系统管理. A tab label SHALL appear only after that page is opened, and SHALL disappear when the tab is closed. Login SHALL open 「车辆管理」 with only that tab. 「新建合同」 SHALL remain a dialog on the contract page and SHALL NOT have its own menu item or tab.

#### Scenario: Login opens the vehicle page

- **WHEN** a user logs in successfully
- **THEN** the shell shows the vehicle page
- **AND** the tab bar contains only 「车辆管理」

#### Scenario: Production and transport tabs appear when opened

- **WHEN** the user opens 生产管理 or 运输清单 from the sidebar
- **THEN** the tab bar contains the corresponding label
- **AND** closing that tab removes its label

#### Scenario: Shell excludes unrelated menus

- **WHEN** an authenticated user views the sidebar
- **THEN** 仪表盘、消纳场地、 and 系统管理 are not shown

### Requirement: Vehicle and contract mock data comes from this site API

The Vue pages SHALL load vehicles, contracts, production rows, and transport rows from authenticated HTTP APIs on `UrbanManagement.XiaoShanResource`. Create, edit, delete, and batch delete for vehicles and contracts SHALL update that same process-local mock through those APIs. Production and transport lists SHALL load from the same process-local mock. The mock SHALL NOT use a database, `UrbanManagement.Core`, or an AppService. Reloading the page SHALL fetch the current process mock again. Restarting the process SHALL restore the seed data. A selected PDF on the contract dialog SHALL be sent only as a file name, SHALL be rejected unless its extension is `.pdf`, and SHALL be rejected when larger than 20MB. The site SHALL NOT upload that file to Attachment. 「批量导入」 SHALL NOT read a file. 「批量上报」 on contracts, production, and transport pages SHALL NOT call the urban admin or an external system; selected rows SHALL keep or become a reported status label as defined for that page.

#### Scenario: Opening the vehicle page loads mock data from the API

- **WHEN** an authenticated user opens 车辆管理
- **THEN** the page requests the XiaoShanResource vehicle API
- **AND** the table shows the mock rows returned by that API

#### Scenario: Saving a contract updates the site mock

- **WHEN** the user saves a new contract whose 合同编号, 购买方, and 收货地址 are filled
- **THEN** the browser sends the contract to the XiaoShanResource contract API
- **AND** a later fetch in the same process returns the new row with 上报状态 「已发送」

#### Scenario: Process restart restores seed data

- **WHEN** the XiaoShanResource process restarts and the user loads the list again
- **THEN** the API returns the seed data

#### Scenario: Opening production loads production mock API

- **WHEN** an authenticated user opens 生产管理
- **THEN** the page requests the XiaoShanResource production API
- **AND** the table shows the mock rows returned by that API

#### Scenario: Opening transport loads transport mock API

- **WHEN** an authenticated user opens 运输清单
- **THEN** the page requests the XiaoShanResource transport API
- **AND** the table shows the mock rows returned by that API

## ADDED Requirements

### Requirement: Production management mock list matches the reference page

XiaoShanResource SHALL provide a 生产管理 page at route `/productions`. The page SHALL offer filters for 标识编号, 批次编号, 生产日期, and 上报状态, plus 搜索 and 重置. The page SHALL show a 批量上报 action. The table SHALL include selection, 序号, 标识编号, 批次编号, 产品名称, 生产日期, 生产量/吨, 发送状态, 发送时间, and a per-row 刷新上报 action. The page SHALL show a total for 生产量/吨 over the current result set and SHALL paginate the mock list. Seed values SHALL follow `_tmp/萧山资源化利用/1116` visible samples (product names such as 再生填料 / 再生土, reported status 「已上报」). 批量上报 and 刷新上报 SHALL only update process-local report status and send time.

#### Scenario: Filter and total on production page

- **WHEN** an authenticated user opens 生产管理 and applies filters
- **THEN** the table shows matching mock rows only
- **AND** the 生产量/吨 total reflects the filtered result set

#### Scenario: Batch report updates production mock status

- **WHEN** the user selects one or more production rows and clicks 批量上报
- **THEN** those rows show a reported status in the mock
- **AND** no external city-platform HTTP call is made

### Requirement: Transport list mock matches the reference page

XiaoShanResource SHALL provide a 运输清单 page at route `/transports`. The page SHALL offer filters for 车牌号, 运输人, 产品, 运输状态, 上报状态, 出货时间 range, and 收货时间 range, plus 搜索 and 重置. The page SHALL show a 批量上报 action. The table SHALL include selection, 序号, 车牌号, 合同编号, 产品, 产品净重/吨, origin and unload summaries as visible on the reference, 出货时间, 出货凭证, 收货时间, and 收货凭证. The page SHALL show a total for 产品净重/吨 over the current result set and SHALL paginate the mock list. 出货凭证 and 收货凭证 SHALL expose a view action that shows mock metadata only (no binary upload). 批量上报 SHALL only update process-local report status and SHALL NOT call an external system.

#### Scenario: Transport list shows net weight and contract

- **WHEN** an authenticated user opens 运输清单
- **THEN** each visible mock row includes 车牌号, 合同编号, 产品, and 产品净重/吨
- **AND** the page shows a 产品净重/吨 total for the current result set

#### Scenario: Voucher view does not upload files

- **WHEN** the user activates 出货凭证 or 收货凭证 on a transport row
- **THEN** the UI shows mock voucher metadata for that row
- **AND** the site does not store or upload image/PDF bytes for that action
