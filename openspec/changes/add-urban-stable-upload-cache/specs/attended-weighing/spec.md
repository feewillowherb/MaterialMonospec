## MODIFIED Requirements

### Requirement: Force WaitingForDeparture when record exists and weight is above threshold

WeighingStateManager SHALL prevent regression from WaitingForDeparture to WeightStabilized or WaitingForStability when a weighing record already exists and weight remains above threshold. When `EnableUploadOnStable` is true on the Urban weighing path and the produced-plate hold for that open record reaches 900 seconds without off-scale, this force MUST NOT keep the cycle closed: the open record id MUST be cleared and status MUST become WaitingForStability while weight remains above threshold. Until that 900-second edge, or whenever stable upload is off, the force rule remains in effect.

#### Scenario: State forced to WaitingForDeparture

- **WHEN** a weighing record exists (recordId > 0), weight > MinWeightThreshold, and computed state is WeightStabilized or WaitingForStability
- **AND** the Urban 900-second stable-upload fallback has not released that record
- **THEN** state SHALL be forced to WaitingForDeparture

#### Scenario: Nine-hundred-second fallback returns to WaitingForStability

- **WHEN** `EnableUploadOnStable` is true on the Urban weighing path, the open record's produced-plate hold is at least 900 seconds old, weight remains above MinWeightThreshold, and off-scale has not occurred
- **THEN** the open record id MUST be cleared
- **AND** state MUST be WaitingForStability
- **AND** state MUST NOT be OffScale solely because the hold expired

### Requirement: Subscribe to ILocalEventBus external events on StartAsync

AttendedWeighingOrchestrator SHALL subscribe to:
- LicensePlateRecognizedEventData → delegate to PlateNumberService
- GhostGateSessionResetEventData → remove abandoned plate and publish updated plate
- SettingsSavedEventData → refresh runtime configuration (EnableLatestPlateNumber, EnablePlateRewrite, EnableMatchOnStable, EnableUploadOnStable)

#### Scenario: License plate event triggers plate cache update

- **WHEN** LicensePlateRecognizedEventData with plate "京A12345" is received
- **THEN** SHALL call PlateNumberService recognition method and publish PlateNumberChangedEventData

#### Scenario: Ghost gate session reset

- **WHEN** GhostGateSessionResetEventData with AbandonedPlateNumber="京A12345" is received
- **THEN** SHALL remove the plate from cache and publish PlateNumberChangedEventData with updated most frequent plate

#### Scenario: Settings saved refreshes runtime config

- **WHEN** SettingsSavedEventData is received
- **THEN** SHALL reload EnableLatestPlateNumber, EnablePlateRewrite, EnableMatchOnStable, and EnableUploadOnStable from settings
