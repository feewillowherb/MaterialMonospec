## ADDED Requirements

### Requirement: UrbanWeighingRecord SiteType column is UrbanSiteType int

EF Core mapping for `UrbanWeighingRecord.SiteType` SHALL use non-nullable `UrbanSiteType` stored as integer. A migration MUST convert historical string values to enum integers before enforcing non-nullable int storage. Unparseable or null historical values MUST become `Construction` (0). The CLR property name MUST remain `SiteType`.

#### Scenario: Migration maps known wire strings

- **WHEN** the SiteType migration runs against a row with `SiteType = '2'`
- **THEN** the row SHALL store integer value for `UrbanSiteType.Disposal`

#### Scenario: Migration defaults unknown values

- **WHEN** the SiteType migration runs against a row with null or unrecognized `SiteType` text
- **THEN** the row SHALL store `UrbanSiteType.Construction` (0)
