## ADDED Requirements

### Requirement: Standalone SolidWaste database upgrade
The standalone tool SHALL inspect a supported SolidWaste SQLite source read-only and SHALL write an upgraded database only to a separate new destination. The program SHALL publish a verified copy and SHALL return a nonzero exit code with a diagnostic on failure.

#### Scenario: Upgrade a supported source
- **WHEN** the operator selects a supported source and a new destination
- **THEN** the tool SHALL produce a consistent copy with the target kernel and SolidWaste schema
- **AND** the tool SHALL verify SQLite integrity and preservation of kernel IDs before publication

#### Scenario: Upgrade cannot complete
- **WHEN** the source is invalid, fields conflict or the destination already exists
- **THEN** the command SHALL fail while preserving the source and any existing destination
