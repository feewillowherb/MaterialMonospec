## MODIFIED Requirements

### Requirement: Settings UI selects TransmissionFormatType

The settings UI SHALL present communication format as a selection control bound to `TransmissionFormatType`, displaying enum Descriptions `(tF0)` / `(tF1)`. The UI MUST NOT use a free-text field for `CommunicationMethod`. When `ScaleType` is `Yaohua`, the UI MUST enable both `TransmissionFormatType0` and `TransmissionFormatType1`. When `ScaleType` is any non-Yaohua value (including `TestMode`), the UI MUST NOT enable `TransmissionFormatType1`.

#### Scenario: Non-Yaohua cannot select Type1

- **WHEN** user selects a non-Yaohua `ScaleType` (including TestMode)
- **THEN** `(tF1)` MUST be absent or disabled in the format selector

#### Scenario: Yaohua can select Type1

- **WHEN** user selects `ScaleType.Yaohua`
- **THEN** the format selector MUST offer both `(tF0)` and `(tF1)`

#### Scenario: Switching format resets CommunicationParameter

- **WHEN** user changes `TransmissionFormatType` in settings
- **THEN** `CommunicationParameter` MUST be reset to the default for the current `ScaleType` and new format (Yaohua default `"A"`)

### Requirement: Protocol router resolves ScaleType times TransmissionFormatType

The system SHALL provide `ITruckScaleProtocolRouter` that resolves every in-enum pair `(ScaleType, TransmissionFormatType)` to an `IScaleTransmissionProtocol`. Callers of weighing flows SHALL continue to use `ITruckScaleWeightService` as the facade; the facade SHALL obtain the protocol via the router.

#### Scenario: Resolve Type0 for each ScaleType

- **WHEN** `Resolve` is called with any `ScaleType` and `TransmissionFormatType0`
- **THEN** the router MUST return the device-specific Type0 protocol implementation for that `ScaleType`

#### Scenario: Resolve Yaohua Type1 to continuous-query protocol

- **WHEN** `Resolve` is called with `ScaleType.Yaohua` and `TransmissionFormatType1`
- **THEN** the router MUST return the Yaohua continuous-query Type1 protocol implementation (not the unsupported stub)

#### Scenario: Resolve non-Yaohua Type1 yields unsupported protocol

- **WHEN** `Resolve` is called with a non-Yaohua `ScaleType` and `TransmissionFormatType1`
- **THEN** the router MUST return a shared unsupported protocol that does not parse real Type1 frames

### Requirement: Unsupported or deferred formats throw instead of fake success

An `IScaleTransmissionProtocol` that does not support the active `(ScaleType, TransmissionFormatType)` pair MUST throw on `EnsureSupported` / start / initialize paths. The system MUST NOT report online success with fabricated zero weights for unsupported formats. `ScaleType.Yaohua` with `TransmissionFormatType1` is supported by the continuous-query protocol and MUST NOT use the unsupported stub.

#### Scenario: Initialize fails for non-Yaohua Type1

- **WHEN** `ITruckScaleWeightService.InitializeAsync` is invoked with `TransmissionFormatType1` for a non-Yaohua `ScaleType`
- **THEN** initialization MUST fail by throwing (or propagating) an unsupported/not-implemented error that identifies ScaleType and TransmissionFormatType
- **AND** the service MUST NOT publish successful weight updates as if the format were supported

#### Scenario: Initialize succeeds for Yaohua Type1 continuous query

- **WHEN** `ITruckScaleWeightService.InitializeAsync` is invoked with `ScaleType.Yaohua` and `TransmissionFormatType1` and serial settings are otherwise valid
- **THEN** initialization MUST succeed without treating the pair as unsupported
- **AND** the service MUST be able to publish real-time weight updates from the continuous-query listen path

## ADDED Requirements

### Requirement: Yaohua Type1 uses continuous-query listen without host query writes

For `ScaleType.Yaohua` and `TransmissionFormatType1`, the system SHALL parse serial bytes that arrive on the open port (continuous query / listen) via the facade data-received path. The production Type1 path MUST NOT send query or control command frames to the instrument for the purpose of obtaining weight (Demo-style write-and-poll is forbidden on the production path).

#### Scenario: Type1 consumes arriving serial data

- **WHEN** Yaohua Type1 is active and weight frames arrive on the serial port
- **THEN** the Type1 protocol MUST parse them through `OnDataReceived` (or equivalent continuous read) and contribute to real-time weight updates

#### Scenario: Type1 must not write query commands for weighing

- **WHEN** Yaohua Type1 is obtaining weight for display or weighing
- **THEN** the production path MUST NOT write host query/command frames to the serial port for that purpose

### Requirement: ScaleSettings exposes opaque CommunicationParameter

`ScaleSettings` SHALL expose `CommunicationParameter` as an opaque `string?` shared across transmission formats. Changing `TransmissionFormatType` MUST reset `CommunicationParameter` to the default for the active `ScaleType` and new format. For Yaohua, the default MUST be `"A"`. Protocol implementers SHALL own parsing/interpretation; the facade MUST NOT centrally parse the value into a shared address model. Production Yaohua Type1 MUST NOT use `CommunicationParameter` to build outbound query frames.

#### Scenario: Yaohua default parameter is A

- **WHEN** Yaohua settings are created or TransmissionFormatType is changed while ScaleType is Yaohua
- **THEN** `CommunicationParameter` MUST be `"A"` after reset

#### Scenario: Protocol owns parameter interpretation

- **WHEN** Yaohua Type0 or Type1 needs address-related behavior from `CommunicationParameter`
- **THEN** the Yaohua protocol implementation MUST interpret the opaque string
- **AND** the facade MUST NOT impose a single global address parser for all ScaleTypes

### Requirement: Prefer Yaohua component weights then fall back to stable mode

When Yaohua Type1 continuous query yields tare, gross, and net component weights, weighing logic SHALL prefer those components only when **all three are valid**. If **any one** of tare, gross, or net is invalid (missing, empty, parse failure, or protocol sentinel), the system MUST fall back to the existing stable-weight path driven by the same real-time `WeightUpdates` stream. Type1 MUST keep publishing real-time weights so the stable path remains usable without a second serial session. Multi-value component results MUST use a named `record` (not a tuple).

#### Scenario: All three components valid uses instrument G/T/N

- **WHEN** Yaohua Type1 reports valid tare, gross, and net together
- **THEN** weighing consumption MUST prefer those instrument component weights over computing them solely from the stable-window path

#### Scenario: Any invalid component falls back to stable mode

- **WHEN** Yaohua Type1 reports at least one invalid value among tare, gross, and net
- **THEN** weighing MUST fall back to the existing real-time weight + software stability window path
- **AND** real-time weight updates MUST still be available on the same Type1 session

#### Scenario: Component payload is a named record

- **WHEN** component weights are passed across protocol / facade / weighing boundaries
- **THEN** the type MUST be a named `record`
- **AND** MUST NOT be a C# tuple or `ValueTuple`
