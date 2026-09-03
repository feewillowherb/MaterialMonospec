## MODIFIED Requirements

### Requirement: UrbanWeighingRecordDto extended with sync state fields

The **`ReceiveAsync` wire DTO** (`UrbanWeighingRecordReceiveInputDto`) SHALL accept **legacy-tolerant** inbound JSON for fields that older MaterialClient.Urban builds still send, then normalize before persistence:

- `siteType`: SHALL bind as a legacy-tolerant value (string and/or numeric wire such as `"1"` / `"2"` / enum names / recognized aliases). After normalization, persistence MUST use `UrbanSiteType` on the entity. Unrecognized or omitted `siteType` MUST normalize to `UrbanSiteType.Construction`.
- `syncType` / `clientSyncType`: SHALL bind as legacy-tolerant int and/or string values (including client alias `Synced` mapped to `SyncStatus.Success`). Omitted values MUST normalize to `SyncStatus.Pending`.
- `clientRetryCount`: MAY be omitted; omitted MUST normalize to `0`.
- `ProId` SHALL remain required `Guid` (reject missing / null / `Guid.Empty`).
- The receive DTO MUST NOT include `FdBuildLicenseNo`.

The **entity** `UrbanWeighingRecord.SiteType` / sync fields remain strong `UrbanSiteType` / `SyncStatus` (see entity requirement). A future `ReceiveV2` strongly typed wire contract is **out of scope** for this change; `ReceiveAsync` remains the supported path for legacy clients.

#### Scenario: DTO round-trip with UrbanSiteType enum name

- **WHEN** a MaterialClient.Urban POST includes `"siteType": "Disposal"` and a valid `proId`
- **THEN** the system SHALL normalize to `UrbanSiteType.Disposal`, persist, and return success

#### Scenario: Legacy numeric siteType wire

- **WHEN** `ReceiveAsync` receives JSON with `"siteType": "2"` (or numeric `2`) and a valid `proId`
- **THEN** the persisted `UrbanWeighingRecord.SiteType` SHALL be `UrbanSiteType.Disposal`
- **AND** the request MUST NOT fail model binding solely because `siteType` is not an enum name

#### Scenario: Legacy siteType Construction wire

- **WHEN** `ReceiveAsync` receives JSON with `"siteType": "1"` (or numeric `1`) or omits `siteType`
- **THEN** the persisted `SiteType` SHALL be `UrbanSiteType.Construction`

#### Scenario: Legacy sync ints and Synced alias

- **WHEN** the payload includes `"syncType": 0` and `"clientSyncType": 1` or `"clientSyncType": "Synced"`
- **THEN** model binding MUST succeed
- **AND** normalized `ClientSyncType` (when applied to persistence fields that store client sync) SHALL be `SyncStatus.Success` for ordinal/alias `1` / `Synced`

#### Scenario: Receive rejects empty ProId

- **WHEN** `ReceiveAsync` receives a payload with missing `proId`, null `proId`, or `Guid.Empty`
- **THEN** the system SHALL reject the request with a validation or business error
- **AND** MUST NOT persist a weighing record

## ADDED Requirements

### Requirement: ReceiveAsync remains the legacy client ingest path

UrbanManagement SHALL keep `IUrbanWeighingRecordAppService.ReceiveAsync` as the HTTP ingest entry for older MaterialClient.Urban weighing uploads. The system MUST NOT require clients to call a `ReceiveV2` (or otherwise renamed) endpoint for this compatibility fix. Introducing `ReceiveV2` is deferred and MUST NOT be delivered by this change.

#### Scenario: Existing receive route accepts legacy payload

- **WHEN** an older client POSTs a complete weighing payload to the existing conventional `urban-weighing-record/receive` route with legacy `siteType` / sync wire values
- **THEN** the server SHALL accept the request after legacy normalization
- **AND** MUST return a `UrbanWeighingRecordReceiveOutputDto` with a non-empty `RecordId` on success
