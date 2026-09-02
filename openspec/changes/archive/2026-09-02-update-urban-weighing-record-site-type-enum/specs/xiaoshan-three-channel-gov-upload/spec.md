## MODIFIED Requirements

### Requirement: Outbound converters only at Gov upload

UrbanManagement SHALL convert domain `UrbanInOutType` and `UrbanSiteType` to Xiaoshan wire values only when assembling Gov payloads. Checkpoint, finished-product, **and weighbridge** converters MUST be separate types (or separate static members). Converters MUST be static or invoked from payload `From*` factories and MUST NOT be registered in DI. Persistence MUST keep domain enums. Weighbridge `inOutType` MUST be `0` for Enter and `1` for Exit. Weighbridge wire `siteType` MUST be `"2"` for `UrbanSiteType.Disposal` and `"1"` otherwise. Checkpoint and product `deviceID` MUST be `01` for Enter and `02` for Exit. Passage payloads MUST omit `goodsWeight` when absent and MUST NOT send `0` as a fake weight.

#### Scenario: Weighbridge SiteType converter

- **WHEN** `GovSyncWeightPayload.FromRecord` builds an outbound weighing payload
- **THEN** `siteType` MUST come from `XiaoshanWeighbridgeConverter.SiteType(record.SiteType)` (or equivalent static)
- **AND** MUST NOT copy a free-text column verbatim
