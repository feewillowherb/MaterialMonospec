## REMOVED Requirements

### Requirement: Site type has no runtime behavior in this change

**Reason**: Urban checkpoint and finished-product recognitions must persist passage records instead of weighing.

**Migration**: Urban recognition MUST branch on `LprSiteType` as specified under ADDED Requirements. Non-Urban products remain scale-only and keep the existing weighing path.

## ADDED Requirements

### Requirement: Urban LPR row stores in/out and site nature

Each Urban `LicensePlateRecognitionConfig` SHALL persist `UrbanInOutType` (enter/exit) and `UrbanSiteType` (construction/disposal) in the same settings JSON row as site type. New Urban rows MUST default enter and construction when the operator does not change them. Missing or unrecognized JSON for these properties MUST deserialize to those defaults without failing the rest of the row. Non-Urban hosts MUST NOT require the operator to set these fields.

#### Scenario: Urban add dialog sets site nature

- **WHEN** the Urban host confirms AddLprDialog
- **THEN** the saved LPR row MUST include the selected `UrbanSiteType`
- **AND** MUST include the selected `UrbanInOutType`

#### Scenario: Legacy JSON without the new properties

- **WHEN** an LPR row JSON omits in/out or site nature
- **THEN** loading MUST yield enter and construction for the omitted properties
- **AND** MUST NOT fail to deserialize the rest of the row


### Requirement: Urban LPR site types replace ModesJson enabled flags

On MaterialClient.Urban, whether 地磅、卡口、成品 capabilities are active SHALL be derived from the LPR config collection: at least one row with `LprSiteType` scale, checkpoint, or finished product respectively. Derivation MUST use a named record and static `From*` (no mapper Service, no DI). The client MUST NOT read Weighbridge/Gate/Product enabled flags from `ModesJson` to decide recognition persistence or list tabs.

#### Scenario: Checkpoint LPR enables passage path

- **WHEN** Urban settings contain at least one LPR row with site type checkpoint
- **THEN** checkpoint recognition MUST persist passage records
- **AND** MUST NOT require a ModesJson Gate enabled flag

#### Scenario: No finished-product LPR

- **WHEN** Urban settings contain no LPR row with site type finished product
- **THEN** the client MUST NOT treat Product mode as enabled from leftover `ModesJson`


### Requirement: Urban recognition branches on LPR site type

When the Urban product handles a plate recognition, post-recognition persistence MUST read the matched `LicensePlateRecognitionConfig` site type. Checkpoint and finished-product MUST create an `UrbanPassageRecord` (see `urban-passage-record`). Scale MUST keep the existing weighing path and MUST NOT write a passage record. DeviceManager start/stop, SDK capture, and gate I/O MAY still treat all configured LPR devices as startable devices; they MUST NOT skip starting a device because it is checkpoint or finished product.

#### Scenario: Recognition path uses site type for persistence

- **WHEN** a plate is recognized from a configured Urban LPR device
- **THEN** the persistence action MUST follow that row’s site type (weighing vs passage)
- **AND** MUST NOT ignore checkpoint or finished-product site type for create-record routing
