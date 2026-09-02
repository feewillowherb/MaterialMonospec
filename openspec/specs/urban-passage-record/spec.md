# urban-passage-record Specification

## Purpose
TBD - created by archiving change add-urban-passage-record. Update Purpose after archive.
## Requirements

### Requirement: Single Urban passage entity without weight

Urban SHALL persist checkpoint and finished-product captures as one entity (`UrbanPassageRecord` or equivalent) on `UrbanDbContext`. The entity MUST NOT include a weight column and MUST NOT use `WeighingRecord` or `UrbanWeighingExtension`. Source MUST be stored as `PassageSource` with exactly checkpoint and finished-product values. `UrbanInOutType` and `UrbanSiteType` MUST be written at create time as snapshots. Related files MUST use logical attachment ids with no database foreign keys.

#### Scenario: Checkpoint and product share one table

- **WHEN** a checkpoint capture and a finished-product capture are saved
- **THEN** both MUST be rows of the same entity type
- **AND** MUST differ by `PassageSource`
- **AND** MUST NOT create a weighing record

#### Scenario: Defaults when SDK omits color or vehicle type

- **WHEN** plate color is missing from recognition
- **THEN** `PlateColor` MUST be stored as「无」
- **WHEN** vehicle type is missing
- **THEN** `VehicleType` MUST be stored as「大车」

#### Scenario: Attachments are optional and not padded

- **WHEN** recognition provides zero, one, or two images
- **THEN** the system MUST persist only images that exist
- **AND** MUST NOT duplicate an image to force two slots

### Requirement: LPR checkpoint and product create passage records

When Urban matches a recognition to an LPR config whose site type is checkpoint or finished product, the system MUST create a passage record via an Urban Service with `[UnitOfWork]` on writes. ViewModels MUST NOT inject repositories. Creation MUST use a type-owned factory on the entity (no Service field-by-field assignment). `UrbanInOutType` and `UrbanSiteType` MUST snapshot the matched LPR config row (not 城管配置 / `ModesJson`). Unrecognized plate text MAY be stored as「无」.

#### Scenario: Checkpoint recognition does not weigh

- **WHEN** a plate is recognized on an LPR row with site type checkpoint
- **THEN** the system MUST insert a passage record with `PassageSource` checkpoint
- **AND** MUST NOT call the weighing create path for that recognition

#### Scenario: Scale recognition still weighs

- **WHEN** a plate is recognized on an LPR row with site type scale
- **THEN** the system MUST follow the existing weighing path
- **AND** MUST NOT insert a passage record for that recognition

#### Scenario: Snapshots come from the LPR row

- **WHEN** a passage record is created from a recognition
- **THEN** `UrbanInOutType` and `UrbanSiteType` MUST equal the matched LPR config row
- **AND** MUST NOT be read from 城管配置 `ModesJson`

### Requirement: Dedicated checkpoint and finished-product list tabs

Urban attended UI SHALL add checkpoint and finished-product tabs. Each tab MUST list only passage rows of that `PassageSource`. Columns MUST be plate (store「无」shown as「未识别」), plate color, vehicle type, in/out, site type (工地/消纳), captured time, and right-side large photo only. The tabs MUST NOT show weight, anomaly badge, approve, or a type column.

#### Scenario: Checkpoint tab columns

- **WHEN** the operator opens the checkpoint tab
- **THEN** the list MUST contain only checkpoint passage rows
- **AND** MUST NOT show weight or approve actions

#### Scenario: Large photo only on dedicated tabs

- **WHEN** a passage row has both a small and a large capture image
- **THEN** the right-side photo MUST show only the large image
- **AND** MUST NOT render the small image in the list UI

#### Scenario: Unrecognized plate label

- **WHEN** `PlateNumber` is「无」
- **THEN** the plate column MUST display「未识别」
- **AND** the plate-color column MAY still display「无」

### Requirement: Client uploads passage to UrbanManagement not Gov

MaterialClient.Urban SHALL upload pending checkpoint passage rows to the UrbanManagement checkpoint ingest API and pending finished-product rows to the finished-product ingest API. Weighing cloud upload MUST remain the existing weighing receive API. The client MUST NOT POST Xiaoshan Gov URLs for passage or weighing.

#### Scenario: Checkpoint cloud path

- **WHEN** a pending checkpoint `UrbanPassageRecord` is submitted to the server
- **THEN** the client MUST call the checkpoint ingest API
- **AND** MUST NOT call weighing `ReceiveAsync`
- **AND** MUST NOT call Xiaoshan `inoutRecord/save`

#### Scenario: Scale records unchanged

- **WHEN** a pending weighing record is submitted
- **THEN** the client MUST use the existing weighing receive path

### Requirement: UrbanPassageRecord ProId is required Guid

`UrbanPassageRecord` SHALL persist `ProId` as a non-nullable `Guid`. Passage create/receive paths MUST supply a valid project id and MUST reject `Guid.Empty`.

#### Scenario: Passage created with valid ProId

- **WHEN** a checkpoint or finished-product passage is created via the Urban receive path
- **THEN** `UrbanPassageRecord.ProId` SHALL be set to the supplied non-empty Guid
- **AND** the value SHALL be persisted as non-nullable

#### Scenario: Passage receive rejects empty ProId

- **WHEN** a passage receive payload omits `proId` or supplies `Guid.Empty`
- **THEN** the system SHALL reject the request
- **AND** MUST NOT insert a passage row
