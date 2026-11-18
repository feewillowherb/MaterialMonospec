## MODIFIED Requirements

### Requirement: SolidWaste-only columns live in the SolidWaste context

The SolidWaste host SHALL store SolidWasteType, Street, SolidWasteOrderNumber and Shipper exclusively on SolidWasteWaybillExtension and SolidWasteWeighingExtension in SolidWasteDbContext. Association SHALL use scalar WaybillId or WeighingRecordId with unique indexes, without database foreign keys or EF navigations. Kernel WeighingRecords and Waybills SHALL remain the shared tables for all modes. Normal product reads and writes MUST NOT use the four legacy ExtraProperties keys, fallback to them or copy them into extensions.

#### Scenario: SolidWaste saves product fields
- **WHEN** SolidWaste creates or edits a weighing record or waybill with product input
- **THEN** the four fields SHALL be saved to its extension under the same logical kernel id
- **AND** they SHALL NOT be written to ExtraProperties

#### Scenario: Other products retain kernel storage
- **WHEN** Standard, Urban or Recycle reads its kernel weighing rows
- **THEN** row ids and kernel table ownership SHALL remain unchanged

### Requirement: Existing SolidWaste values are copied without deleting kernel rows

For this change's supported baseline, existing product values SHALL already reside in SolidWaste extensions and the only business field in ExtraProperties SHALL be UseIndependentDisplayedNet. Startup SHALL preserve existing kernel rows and extension values without copying four-field legacy keys or manufacturing missing values. A database outside this baseline SHALL remain unmodified by this change's data transition and SHALL produce an actionable unsupported-baseline diagnostic. Historical key migration or cleanup is outside this change.

#### Scenario: Repeated startup preserves existing data
- **WHEN** the SolidWaste host starts repeatedly on a supported database
- **THEN** existing kernel and extension data SHALL remain unchanged by startup backfill

#### Scenario: Missing product extension
- **WHEN** a historical row lacks an extension
- **THEN** queries SHALL explicitly represent unavailable product data
- **AND** SHALL NOT persist fabricated defaults or reconstruct data from legacy keys

#### Scenario: Unsupported legacy keys are present
- **WHEN** baseline validation finds four-field legacy business data requiring a transition
- **THEN** the transition SHALL stop before writing that database
- **AND** SHALL report the mismatch without deleting keys or overwriting extensions

### Requirement: Hosts that are not the standard client do not migrate these contexts

Standard SHALL migrate only the kernel and StandardDbContext. SolidWaste SHALL migrate only the kernel and SolidWasteDbContext. Urban and Recycle MUST NOT apply either StandardDbContext or SolidWasteDbContext migrations. When no product persistence implementation is loaded, neutral lifecycle integration SHALL perform no product extension write.

#### Scenario: Standard startup is isolated
- **WHEN** Standard applies startup migrations
- **THEN** it SHALL NOT apply SolidWasteDbContext migrations or run SolidWaste backfill

#### Scenario: SolidWaste startup is isolated
- **WHEN** SolidWaste applies startup migrations
- **THEN** it SHALL NOT apply StandardDbContext migrations

#### Scenario: Urban and Recycle startup remains isolated
- **WHEN** Urban or Recycle starts
- **THEN** neither StandardDbContext nor SolidWasteDbContext migrations SHALL run

## ADDED Requirements

### Requirement: Net display flag has one business authority

UseIndependentDisplayedNet SHALL remain authoritative only in Waybill ExtraProperties. Extension snapshots, persistence and normal reads MUST NOT maintain a second business value for it. Existing physical extension columns MAY remain inert for compatibility; published migrations SHALL remain immutable. New extension inserts SHALL succeed with retained physical column constraints.

#### Scenario: Flag values control display consistently
- **WHEN** a waybill has a true, false or absent ExtraProperties flag
- **THEN** display, query, printing and export SHALL use the same canonical value and existing default behavior
- **AND** SHALL NOT consult the old extension column

#### Scenario: New extension is inserted into an existing schema
- **WHEN** SolidWaste creates an extension in a supported database retaining the old flag column
- **THEN** insertion SHALL succeed without requiring a second mapped business flag
- **AND** existing extension fields and logical ids SHALL be preserved
