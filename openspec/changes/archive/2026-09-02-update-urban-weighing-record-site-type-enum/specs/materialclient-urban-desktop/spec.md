## ADDED Requirements

### Requirement: Urban weighing upload includes UrbanSiteType as SiteType

MaterialClient.Urban `UrbanWeighingRecordSubmitDto` SHALL expose `SiteType` as **`UrbanSiteType`** (JSON `siteType`). `UrbanServerUploadService` MUST populate it from the Scale LPR configuration row’s `UrbanSiteType` when available; otherwise MUST use `UrbanSiteType.Construction`. The DTO MUST NOT send a free-text site type string.

#### Scenario: Scale LPR provides Disposal

- **WHEN** submit builds a weighing payload and the matched Scale LPR row has `UrbanSiteType.Disposal`
- **THEN** `UrbanWeighingRecordSubmitDto.SiteType` SHALL be `Disposal`

#### Scenario: No Scale LPR site type available

- **WHEN** submit builds a weighing payload and no Scale LPR `UrbanSiteType` is available
- **THEN** `SiteType` SHALL be `UrbanSiteType.Construction`
