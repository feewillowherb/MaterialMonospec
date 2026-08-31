## Requirements

### Requirement: Each LPR config row has a site type defaulting to scale

Every `LicensePlateRecognitionConfig` SHALL persist a site type with exactly three values: scale (地磅), checkpoint (卡口), and finished product (成品). When the JSON property is missing, null, or unrecognized, the runtime MUST treat the row as scale. New rows created in settings MUST start as scale.

#### Scenario: Legacy JSON without the property

- **WHEN** settings JSON for an LPR row omits the site type property
- **THEN** loading settings MUST yield site type scale for that row
- **AND** MUST NOT fail to deserialize the rest of the row

#### Scenario: New LPR row defaults to scale

- **WHEN** the user adds a license plate recognition device
- **THEN** the new config MUST have site type scale before the user changes it (Urban) or as the only allowed value (non-Urban)

### Requirement: Site type has no runtime behavior in this change

Weighing, plate matching, DeviceManager start/stop, gate I/O, capture, and cloud upload MUST NOT branch on LPR site type. The field MAY be persisted and shown in settings only.

#### Scenario: Recognition path ignores site type

- **WHEN** a plate is recognized from any configured LPR device
- **THEN** device selection, SDK callbacks, and post-recognition actions MUST behave as they do without a site type field
- **AND** MUST NOT skip or prefer a device because its site type is checkpoint or finished product
