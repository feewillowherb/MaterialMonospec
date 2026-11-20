## ADDED Requirements

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
