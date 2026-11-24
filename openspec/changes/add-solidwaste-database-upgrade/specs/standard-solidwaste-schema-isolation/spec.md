## MODIFIED Requirements

### Requirement: Existing SolidWaste values are copied without deleting kernel rows
The standalone SolidWaste database upgrade SHALL copy legacy nonempty SolidWasteType, Street, SolidWasteOrderNumber and Shipper values into the matching extensions while preserving existing extension values, source JSON, kernel rows and logical IDs. The upgrader SHALL report conflicts and SHALL NOT publish the result on conflict. The desktop SHALL NOT execute this transition on an existing deployment.

#### Scenario: Existing legacy values are preserved
- **WHEN** a supported legacy database has nonempty old fields and matching extensions are missing or incomplete
- **THEN** the standalone upgrader SHALL fill missing values in the upgraded copy
- **AND** existing business fields and the independent net display flag SHALL remain unchanged

#### Scenario: Missing historical data
- **WHEN** a historical row has no product extension or nonempty legacy fields
- **THEN** the upgrade SHALL NOT manufacture missing values

#### Scenario: Repeated upgrade
- **WHEN** a verified output is later inspected or upgraded to another new destination
- **THEN** the tool SHALL preserve the existing extensions
