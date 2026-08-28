## MODIFIED Requirements

### Requirement: Config model is extensible for later mode slices

The persisted and API configuration model SHALL use a versioned structured envelope for `ModesJson` and `SettingsJson` that holds Weighbridge/Gate/Product mode settings and static field mappings. Get and Write SHALL serialize and deserialize these envelopes; invalid schema on Write SHALL be rejected. Raw JSON advanced editing MAY remain as a secondary diagnostic path but MUST NOT be the only editing surface after this change.

#### Scenario: Envelope accepts populated mode settings

- **WHEN** configuration is saved with structured mode and settings envelopes
- **THEN** `ModesJson` and `SettingsJson` SHALL persist canonical JSON for those envelopes
- **AND** a subsequent get SHALL round-trip the structured content

#### Scenario: Invalid modes envelope rejected on write

- **WHEN** a write submits `ModesJson` that fails schema validation (for example no enabled modes)
- **THEN** the server SHALL reject the write without incrementing `configVersion`

#### Scenario: Empty legacy JSON materializes defaults on read

- **WHEN** a get returns configuration whose `ModesJson` is `{}` or legacy placeholder
- **THEN** the API/UI SHALL materialize default mode selection with Weighbridge enabled
- **AND** SHALL present settings envelope defaults without requiring manual JSON migration
