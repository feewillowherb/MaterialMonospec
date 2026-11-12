## ADDED Requirements

### Requirement: SolidWaste-only columns live in the SolidWaste context

The standard host SHALL store SolidWaste-only fields on `SolidWasteWaybillExtension` and `SolidWasteWeighingExtension` in `SolidWasteDbContext`. Association to kernel rows SHALL be the scalar `WaybillId` or `WeighingRecordId` only. The system MUST NOT add a database foreign key or an EF navigation for that association. Kernel `WeighingRecords` and `Waybills` SHALL remain the tables for weighing and waybill rows of every `WeighingMode`, including SolidWaste, Urban, and Recycle.

#### Scenario: SolidWaste save writes the extension row

- **WHEN** the standard host saves SolidWaste fields for a waybill or weighing record
- **THEN** it SHALL upsert the matching SolidWaste extension row
- **AND** the kernel weighing or waybill row SHALL remain in the kernel table with the same primary key

#### Scenario: Urban weighing row stays on the kernel table

- **WHEN** an Urban host reads a weighing record whose `WeighingMode` is `UrbanMode`
- **THEN** that row SHALL be loaded from kernel `WeighingRecords`
- **AND** `UrbanWeighingExtension.WeighingRecordId` SHALL still identify that kernel row

### Requirement: Product migrations do not change kernel weighing tables

`SolidWasteDbContext` migrations SHALL be recorded in `__EFMigrationsHistory_SolidWaste`. `StandardDbContext` migrations SHALL be recorded in `__EFMigrationsHistory_Standard`. Neither migration MUST create, alter, or drop kernel `WeighingRecords` or `Waybills`. A new SolidWaste-only column SHALL be added only by a SolidWaste migration.

#### Scenario: SolidWaste migration leaves kernel aggregates unchanged

- **WHEN** `SolidWasteDbContext` applies its initial migration
- **THEN** the SolidWaste extension tables SHALL exist
- **AND** kernel `WeighingRecords` and `Waybills` SHALL keep their existing rows and primary keys

### Requirement: Existing SolidWaste values are copied without deleting kernel rows

After the SolidWaste migration, the standard host SHALL insert extension rows for kernel rows whose stored `WeighingMode` is `SolidWaste` when that logical id is not already present. The copy SHALL read the existing SolidWaste `ExtraProperties` keys. It MUST NOT delete the kernel row and MUST NOT remove those keys. A later startup MUST NOT overwrite an extension row that already exists for that logical id.

#### Scenario: SolidWaste waybill gains an extension row

- **WHEN** a kernel waybill has `WeighingMode.SolidWaste` and no `SolidWasteWaybillExtension` for its id
- **AND** the standard host runs the backfill
- **THEN** an extension row SHALL be inserted with that `WaybillId`
- **AND** the kernel waybill row SHALL still exist

#### Scenario: Existing extension row is kept

- **WHEN** an extension row already exists for a SolidWaste waybill id
- **AND** the backfill runs again
- **THEN** that extension row SHALL be left unchanged

### Requirement: Hosts that are not the standard client do not migrate these contexts

Urban and Recycle hosts MUST NOT apply `StandardDbContext` or `SolidWasteDbContext` migrations. When the SolidWaste module is not loaded, SolidWaste extension writes SHALL be a no-op.

#### Scenario: Urban startup does not open the SolidWaste migration history

- **WHEN** the Urban host applies startup migrations
- **THEN** it MUST NOT apply `SolidWasteDbContext` or `StandardDbContext` migrations
