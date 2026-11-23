## MODIFIED Requirements

### Requirement: Transport list shows stored trip facts

The transport page SHALL show `WeighedAt` as 「过磅时间」, the stored `TransporterName` snapshot, and `UnloadPoint` as 「卸点」. `WeighedAt` SHALL use the same `Asia/Shanghai` display rule as vehicle creation time when its kind is UTC, and SHALL keep an unspecified clock time unchanged. Status SHALL be 「待补皮重」 when tare is missing, 「待收货」 when the row is weighed and `ReceivingTime` is empty, and 「已收货」 when `ReceivingTime` is present. The page SHALL NOT show the old phase filter, the transport batch-report button, or the selection column used only by that button. For rows that are not 「已收货」, the page SHALL offer a 删除 action that asks for confirmation before calling the transport delete API.

#### Scenario: Weighed row waiting for receipt

- **WHEN** a transport row has a tare and no `ReceivingTime`
- **THEN** the list status is 「待收货」
- **AND** 过磅时间 shows `WeighedAt`
- **AND** 卸点 shows `UnloadPoint`

#### Scenario: Transport batch report control is absent

- **WHEN** an authenticated user opens 运输清单
- **THEN** the page has no phase filter, no 批量上报 button, and no selection column

#### Scenario: Delete is shown only before receipt

- **WHEN** a transport row has no `ReceivingTime`
- **THEN** the row shows 删除 alongside 收货
- **WHEN** a transport row has `ReceivingTime`
- **THEN** the row shows 查看 only and has no 删除 action

#### Scenario: Delete asks for confirmation

- **WHEN** the user clicks 删除 on an eligible row
- **THEN** a confirmation dialog appears before any delete request is sent

### Requirement: Transport delete soft-removes unreceived rows

The Recycle transport service SHALL expose delete for the bound SourceProId. Delete SHALL set the transport aggregate soft-deleted through the existing ABP audit delete path and SHALL remove the row from authenticated list results. Delete SHALL reject rows that already have `ReceivingTime`.

#### Scenario: Soft delete succeeds

- **WHEN** `DELETE /api/transports/{id}` targets a row without `ReceivingTime` in the bound project
- **THEN** the response is successful with no body
- **AND** a subsequent list request does not return that id

#### Scenario: Received row cannot be deleted

- **WHEN** `DELETE /api/transports/{id}` targets a row with `ReceivingTime`
- **THEN** the service rejects the delete
- **AND** the row remains in the list