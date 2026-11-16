## ADDED Requirements

### Requirement: XiaoShanResource login uses SSO product 5041

`UrbanManagement.XiaoShanResource` SHALL render its own login page titled 「萧山资源化利用网页端」. The browser SHALL submit the account and password only to this site. The site SHALL send `POST /GetToken` with `switchType` 0, `productType` 2, and `toProductIds` containing only the configured Web product code. The committed configuration SHALL set that code to 5041. The login page SHALL NOT accept a project switch, a product switch, or a caller-supplied identity.

#### Scenario: Password is submitted to this site

- **WHEN** a user submits an account and password on the XiaoShanResource login page
- **THEN** the browser sends those values only to XiaoShanResource
- **AND** XiaoShanResource calls the configured SSO `POST /GetToken` with `switchType` 0, `productType` 2, and product code 5041

#### Scenario: Product mismatch or SSO failure creates no session

- **WHEN** SSO rejects the password, is unavailable, or returns a product code other than 5041
- **THEN** XiaoShanResource creates no `XiaoShanResource.Session` cookie
- **AND** the login page shows a failure

### Requirement: Local session is a distinct cookie

XiaoShanResource SHALL create cookie `XiaoShanResource.Session` only when the SSO business code is 200 and the returned product code is 5041. The cookie SHALL carry the user identifier, user name, and accepted product code. The SSO token SHALL NOT be written to the cookie, logs, or a database. `POST /logout` SHALL delete only this cookie and return the browser to the login page. Logout SHALL NOT call SSO `logout`.

#### Scenario: Matching product login

- **WHEN** SSO returns business code 200 and product code 5041
- **THEN** XiaoShanResource creates `XiaoShanResource.Session`
- **AND** the response available to the page does not expose the SSO token

#### Scenario: Logout clears only this site

- **WHEN** an authenticated user submits `POST /logout`
- **THEN** `XiaoShanResource.Session` is removed
- **AND** the browser is sent to the XiaoShanResource login page

### Requirement: Authenticated shell shows only the three pictured surfaces

After login, XiaoShanResource SHALL serve a Vue 3 and Element Plus shell. The header title SHALL be 「萧山资源化利用网页端」 and SHALL show the session user name. The sidebar SHALL contain only 「车辆管理」 and 「合同管理」. A tab label SHALL appear only after that page is opened, and SHALL disappear when the tab is closed. Login SHALL open 「车辆管理」 with only that tab. 「新建合同」 SHALL be a dialog on the contract page and SHALL NOT have its own menu item or tab. The shell SHALL NOT show 仪表盘, 消纳场地, 生产管理, 运输清单, or 系统管理.

#### Scenario: Login opens the vehicle page

- **WHEN** a user logs in successfully
- **THEN** the shell shows the vehicle page
- **AND** the tab bar contains only 「车辆管理」

#### Scenario: Contract tab appears when opened

- **WHEN** the user opens 合同管理 from the sidebar
- **THEN** the tab bar also contains 「合同管理」
- **AND** closing that tab removes its label

### Requirement: Vehicle and contract mock data comes from this site API

The Vue pages SHALL load vehicles and contracts from authenticated HTTP APIs on `UrbanManagement.XiaoShanResource`. Create, edit, delete, and batch delete SHALL update that same process-local mock through those APIs. The mock SHALL NOT use a database, `UrbanManagement.Core`, or an AppService. Reloading the page SHALL fetch the current process mock again. Restarting the process SHALL restore the seed data. A selected PDF SHALL be sent only as a file name, SHALL be rejected unless its extension is `.pdf`, and SHALL be rejected when larger than 20MB. The site SHALL NOT upload that file to Attachment. 「批量导入」 SHALL NOT read a file. 「批量上报」 SHALL NOT call the urban admin or an external system, and selected rows SHALL remain 「已发送」.

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

### Requirement: XiaoShanResource does not join the existing gateway

XiaoShanResource SHALL listen on its own port. This change SHALL NOT add the site to the YARP catch-all and SHALL NOT publish it from `um-gateway`. The same `deploy/docker/compose.yaml` SHALL run it as `um-xiaoshanresource`, image `urbanmanagement-xiaoshanresource` with tag `UM_TAG`, publishing host port `UM_XIAOSHAN_PUBLIC_PORT` (default 5334) to container port 8080. The container SHALL take `AdminSso:BaseUrl` from `UM_ADMIN_SSO_BASE_URL` and SHALL set `AdminSso:WebProductCode` to 5041. It SHALL NOT receive the UrbanManagement connection string, SHALL NOT mount the shared Hosting `appsettings.Production.json`, and SHALL NOT wait for `um-migrator`. Anonymous health checks `GET /health/live` and `GET /health/ready` SHALL return HTTP 200 without connecting to the UrbanManagement database.

#### Scenario: Health check does not require the UrbanManagement database

- **WHEN** `GET /health/ready` is requested on XiaoShanResource
- **THEN** the response is HTTP 200
- **AND** the site does not open the UrbanManagement database
