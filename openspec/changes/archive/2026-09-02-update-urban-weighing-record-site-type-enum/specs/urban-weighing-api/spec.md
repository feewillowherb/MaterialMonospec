## MODIFIED Requirements

### Requirement: UrbanWeighingRecord extended fields

The `UrbanWeighingRecord` entity SHALL include extended fields including `SiteType` as **non-nullable `UrbanSiteType`** (default `Construction`), `ProId` as non-nullable `Guid`, sync fields as `SyncStatus` / non-nullable retry counts, and other vehicle/project fields as previously specified. The entity MUST NOT include `FdBuildLicenseNo`. `SnapImages` MUST NOT exist. Property name MUST remain `SiteType` (MUST NOT rename to `UrbanSiteType`).

#### Scenario: SiteType persisted as UrbanSiteType

- **WHEN** a weighing record is created or received with `siteType` of `Disposal`
- **THEN** `UrbanWeighingRecord.SiteType` SHALL equal `UrbanSiteType.Disposal`
- **AND** the database column SHALL store the enum as an integer

#### Scenario: Missing siteType defaults to Construction

- **WHEN** Receive omits `siteType` or the client sends the Construction value
- **THEN** the persisted `SiteType` SHALL be `UrbanSiteType.Construction`

#### Scenario: Receive rejects empty ProId

- **WHEN** `ReceiveAsync` receives a payload with missing `proId`, null `proId`, or `Guid.Empty`
- **THEN** the system SHALL reject the request with a validation or business error
- **AND** MUST NOT persist a weighing record

### Requirement: UrbanWeighingRecordDto extended with sync state fields

The receive / DTO surface SHALL expose `SiteType` as **`UrbanSiteType`** (JSON `siteType`, string enum name). `ProId` SHALL be required `Guid`. The receive DTO MUST NOT include `FdBuildLicenseNo`.

#### Scenario: DTO round-trip with UrbanSiteType

- **WHEN** a MaterialClient.Urban POST includes `"siteType": "Disposal"` and a valid `proId`
- **THEN** the system SHALL deserialize to `UrbanSiteType.Disposal`, persist, and return success
