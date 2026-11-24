# recycle-web-persistence-api Specification

## Purpose
TBD - created by archiving change add-recycle-web-abp-module. Update Purpose after archive.
## Requirements
### Requirement: Business pages use Recycle application services

The vehicle, contract, daily-production, and transport pages on `UrbanManagement.Recycle` SHALL read and write through the existing Recycle application services for the bound SourceProId. The in-memory mock store SHALL be removed. Identifiers exchanged with the page SHALL be the persistent Guid values. Restarting the site SHALL leave previously saved rows available.

#### Scenario: Vehicle survives restart

- **WHEN** an authenticated user creates a vehicle and the site process starts again
- **THEN** the vehicle list returns that same vehicle
- **AND** the list does not come from the removed memory store

#### Scenario: Contract details stay with the contract service

- **WHEN** an authenticated user saves a contract with product lines and more than one transporter
- **THEN** the contract, its details, and its transporter rows are stored by the Recycle contract service
- **AND** the page reads those rows back from that service

### Requirement: Page weights stay exact

The pages SHALL display and submit kilogram values and their exact tonne conversion from the Recycle DTOs. A weight input SHALL NOT round or fix the value to one decimal place. Changing a vehicle tare or a company name SHALL NOT rewrite the tare, owner, transporter, or company snapshot already stored on a transport or contract row.

#### Scenario: Decimal kilograms remain decimal

- **WHEN** a user enters a tare of 1234.5 kilograms
- **THEN** the saved vehicle tare is 1234.5 kilograms
- **AND** the page shows the exact tonne conversion 1.2345

#### Scenario: Later catalog edit keeps the old snapshot

- **WHEN** a transport row has already stored a vehicle tare and the vehicle tare is edited afterward
- **THEN** the transport row keeps the tare stored at receiving time

### Requirement: Transport completion uses the same project

The transport page SHALL submit contract, material, and receiving completion through the Recycle transport service. The service SHALL reject a contract or material that belongs to another project. A missing or disabled vehicle SHALL leave tare and net empty. The page SHALL NOT mark a city-platform send as succeeded.

#### Scenario: Completion cannot cross projects

- **WHEN** a transport completion names a contract or material outside the bound SourceProId
- **THEN** the transport service rejects the completion
- **AND** the transport row does not gain that contract or material snapshot

#### Scenario: No external response is not success

- **WHEN** a user triggers a batch or platform report from the page and no external platform response has been recorded
- **THEN** the row sync status is not Succeeded

### Requirement: Vehicle list shows stored facts only

The vehicle page SHALL show each vehicle's `CreationTime` as `Asia/Shanghai` clock time in `yyyy-MM-dd HH:mm`. A UTC instant at 16:00 or later SHALL display on the next calendar day. The page SHALL NOT show a vehicle run-status column, run-status filter, run-status editor, import action, or a city-report column. The existing vehicle report action SHALL remain available.

#### Scenario: Creation time crosses the UTC date boundary

- **WHEN** a vehicle `CreationTime` is 2026-11-19 16:30 UTC
- **THEN** the vehicle list shows 2026-11-20 00:30

#### Scenario: Placeholder vehicle controls are absent

- **WHEN** an authenticated user opens 车辆管理
- **THEN** the page has no 车辆状态 column, filter, or editor
- **AND** the page has no 批量导入 action and no 市上报 column

### Requirement: Contract report status uses the stored enum

The contract page SHALL display `None` and `Pending` as 「未上报」, `Succeeded` as 「已上报」, and `Failed` as 「上报失败」. Filters SHALL compare the stored enum. The 「未上报」 filter SHALL match both `None` and `Pending`. The page SHALL show 「已上报」 only for `Succeeded`, which remains limited to a recorded platform response code of 200. After a contract batch report returns, including failure or partial success, the page SHALL reload the contract list.

#### Scenario: Unreported filter matches both open states

- **WHEN** the user filters 合同管理 by 「未上报」
- **THEN** rows stored as `None` and rows stored as `Pending` are both included
- **AND** a row stored as `Succeeded` is excluded

#### Scenario: Failed batch report still refreshes the list

- **WHEN** a contract batch report returns a failure or a partial success
- **THEN** the page reloads the contract list before showing the result

### Requirement: Contract page does not offer a placeholder attachment

The contract page SHALL NOT offer a PDF picker, a list action that only shows a file name, or an attachment column. A new contract SHALL start with an empty producer. The page SHALL validate required contract fields before submit.

#### Scenario: New contract starts blank

- **WHEN** the user opens 新建合同 twice
- **THEN** the producer field is empty both times

### Requirement: Transport list shows stored trip facts

The transport page SHALL show `WeighedAt` as 「过磅时间」, the stored `TransporterName` snapshot, and `UnloadPoint` as 「卸点」. `WeighedAt` SHALL use the same `Asia/Shanghai` display rule as vehicle creation time when its kind is UTC, and SHALL keep an unspecified clock time unchanged. Status SHALL be 「待补皮重」 when tare is missing, 「待收货」 when the row is weighed and `ReceivingTime` is empty, and 「已收货」 when `ReceivingTime` is present. The page SHALL NOT show the old phase filter, the transport batch-report button, or the selection column used only by that button.

#### Scenario: Weighed row waiting for receipt

- **WHEN** a transport row has a tare and no `ReceivingTime`
- **THEN** the list status is 「待收货」
- **AND** 过磅时间 shows `WeighedAt`
- **AND** 卸点 shows `UnloadPoint`

#### Scenario: Transport batch report control is absent

- **WHEN** an authenticated user opens 运输清单
- **THEN** the page has no phase filter, no 批量上报 button, and no selection column

### Requirement: Transport completion feedback uses the HTTP result

The receive form SHALL still preview the selected contract buyer and address. Saving SHALL submit `ContractId`, `ContractDetailId`, and `MaterialId` and SHALL run the existing service validation. The service SHALL continue to store the contract `ShipAddress` as the unload point. `ReceivingTime` SHALL remain editable. Success and failure messages SHALL come from the HTTP status and response body. A manual weigh dialog SHALL start with an empty plate and an empty gross weight, and SHALL keep the existing weight precision.

#### Scenario: Receive error is the response body

- **WHEN** transport completion is rejected
- **THEN** the page shows the error from the response body
- **AND** the page does not substitute a fixed success sentence

#### Scenario: Manual weigh opens empty

- **WHEN** the user opens 过磅 for the first time and again after closing it
- **THEN** the plate and gross weight are empty both times

### Requirement: Production management stays hidden

The current Recycle Web shell SHALL NOT show 生产管理. Opening `/productions` SHALL land on 车辆管理. The daily-production API SHALL remain available.

#### Scenario: Hidden production route returns to vehicles

- **WHEN** an authenticated user opens `/productions`
- **THEN** the shell shows 车辆管理
- **AND** the sidebar does not contain 生产管理

### Requirement: Transport rows without a plate stay visible

The transport list SHALL show 「—」 for a row whose `PlateNo` is empty, and the row SHALL keep its receive and view actions. A plate filter SHALL NOT return rows without a plate. The receiving panel SHALL show 「—」 for an empty plate until a vehicle is selected.

#### Scenario: Row without a plate is listed

- **WHEN** a transport row was received with an empty `PlateNumber`
- **THEN** the list shows 「—」 in the plate column
- **AND** the row offers 收货

#### Scenario: Plate filter skips rows without a plate

- **WHEN** the user searches the transport list by a plate
- **THEN** rows without a plate are not returned

#### Scenario: Receiving panel shows an empty plate

- **WHEN** the user opens the receiving panel of a row without a plate
- **THEN** the plate shows 「—」

### Requirement: Receiving panel selects the vehicle plate

The receiving panel SHALL show the plate of the transport row. For a row that is not received, the panel SHALL let the user replace the plate only by searching and selecting a vehicle of the current project. The panel SHALL NOT accept a typed plate that does not match a listed vehicle. For a received row, the panel SHALL show the plate as read-only.

#### Scenario: Panel shows the current plate

- **WHEN** the user opens the receiving panel of a transport row
- **THEN** the panel shows the row's plate

#### Scenario: User searches vehicles

- **WHEN** the user starts a plate change and types part of a plate
- **THEN** the options are the enabled vehicles of the current project whose plate contains the text
- **AND** the panel shows no other options

#### Scenario: Received row keeps its plate

- **WHEN** the user opens the receiving panel of a received row
- **THEN** the plate is shown as read-only and there is no plate change action

### Requirement: Saving a new plate applies the selected vehicle

`PUT /api/transports/{id}` SHALL accept an optional plate. When the plate differs from the stored one, the service SHALL require an enabled vehicle with that plate in the same project, store the new plate, and refresh the tare, net, owner and transporter snapshots from that vehicle. The net weight SHALL be recomputed from the stored gross weight. When the plate is missing from the request or unchanged, the service SHALL leave the plate and its snapshots unchanged.

#### Scenario: Vehicle exists

- **WHEN** the user saves the receiving panel with a plate that belongs to an enabled vehicle of the project
- **THEN** the transport row shows the new plate
- **AND** tare, net and transporter come from that vehicle

#### Scenario: Vehicle is unknown

- **WHEN** the request carries a plate that no enabled vehicle of the project has
- **THEN** the service rejects the save with `RECYCLE:VEHICLE`
- **AND** the transport row keeps its previous plate and snapshots

#### Scenario: Plate unchanged

- **WHEN** the user saves the receiving panel without changing the plate
- **THEN** the plate and its snapshots are unchanged

#### Scenario: Row already received

- **WHEN** a request carries a different plate for a row that already has `ReceivingTime`
- **THEN** the service rejects the save with `RECYCLE:TRANSPORT_RECEIVED`

### Requirement: Vehicle search can exclude disabled vehicles

`GET /api/vehicles` SHALL accept an `enabledOnly` flag. When it is true, the result SHALL contain only enabled vehicles of the current project. Without the flag, the result SHALL be unchanged.

#### Scenario: Enabled vehicles only

- **WHEN** `GET /api/vehicles` is called with `enabledOnly=true`
- **THEN** every returned vehicle is enabled

#### Scenario: Vehicle page is unchanged

- **WHEN** `GET /api/vehicles` is called without `enabledOnly`
- **THEN** enabled and disabled vehicles are returned as before

