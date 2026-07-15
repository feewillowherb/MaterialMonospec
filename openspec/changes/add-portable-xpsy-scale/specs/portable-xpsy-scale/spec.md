## ADDED Requirements

### Requirement: Scale settings expose PortableXPSY type

MaterialClient SHALL provide a truck-scale type for portable XP-SY instruments. The `ScaleType` enum MUST include a value whose display description is `便携式XP-SY`. The settings UI scale-type options MUST include this value so operators can select and persist it via existing `ScaleSettings` / `ISettingsService`.

#### Scenario: Operator selects portable XP-SY in settings

- **WHEN** the operator opens system settings and views the scale type dropdown
- **THEN** the options MUST include `便携式XP-SY`
- **AND** saving with that selection MUST persist `ScaleType` as the PortableXPSY enum value

### Requirement: PortableXPSY forces ASCII frame receive path

When `ScaleSettings.ScaleType` is PortableXPSY, `TruckScaleWeightService` initialization MUST configure the ASCII/`=` receive path regardless of `CommunicationMethod` (including when it is `TF0`). The service MUST NOT use the Yaohua or DingSong HEX frame parsers for this scale type.

#### Scenario: Initialize with PortableXPSY and TF0 communication method

- **WHEN** `InitializeAsync` is called with `ScaleType` PortableXPSY and `CommunicationMethod` equal to `TF0`
- **THEN** the service MUST open the configured serial port using the PortableXPSY ASCII receive path
- **AND** MUST NOT treat incoming data as 12-byte HEX STX/ETX frames for that session

### Requirement: PortableXPSY frame sync and weight parse

For PortableXPSY, the service MUST recognize a 9-byte ASCII frame consisting of an 8-character payload followed by `=` (0x3D). Payload characters MUST be limited to digits, `.`, and `-`. The service MUST reverse the 8-character payload, parse the reversed text with invariant culture as a floating-point weight from the device, then apply the existing scale-unit conversion and publish the result on `WeightUpdates`. The service MUST NOT apply the legacy string validator that requires `±` + eight digits + hex letter.

#### Scenario: Positive weight frame 70.15

- **WHEN** the serial stream delivers the frame `51.07000=`
- **THEN** the parsed device weight before unit conversion MUST be 70.15
- **AND** a corresponding value MUST be published on `WeightUpdates` after existing `ConvertWeight`

#### Scenario: Negative weight frame -70.15

- **WHEN** the serial stream delivers the frame `51.0700-=`
- **THEN** the parsed device weight before unit conversion MUST be -70.15

#### Scenario: Integer-style field sample 1510

- **WHEN** the serial stream delivers the frame `.0151000=`
- **THEN** the parsed device weight before unit conversion MUST be 1510

#### Scenario: Invalid legacy string format is not required

- **WHEN** a valid PortableXPSY payload such as `51.07000` is received with trailing `=`
- **THEN** the frame MUST be accepted under PortableXPSY rules
- **AND** MUST NOT be rejected solely because it fails the `±########[A-F]` legacy string pattern

### Requirement: Continuous PortableXPSY frames without protocol mix-up

When ScaleType is PortableXPSY, consecutive valid 9-byte frames MUST each be parseable independently. Yaohua HEX, DingSong HEX, and TestMode behavior MUST remain unchanged when those types are selected.

#### Scenario: Back-to-back identical frames

- **WHEN** the serial stream delivers `51.07000=51.07000=` under PortableXPSY
- **THEN** the service MUST successfully parse both frames as device weight 70.15 (before conversion)

#### Scenario: Other scale types unaffected

- **WHEN** ScaleType is Yaohua, DingSong, or TestMode
- **THEN** PortableXPSY-specific receive and parse rules MUST NOT alter that type’s existing receive behavior
