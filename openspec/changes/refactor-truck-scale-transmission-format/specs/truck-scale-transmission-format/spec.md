## ADDED Requirements

### Requirement: TransmissionFormatType is the authority for scale communication format

The system SHALL expose enum `TransmissionFormatType` with members `TransmissionFormatType0` (Description `(tF0)`) and `TransmissionFormatType1` (Description `(tF1)`). `ScaleSettings` SHALL persist `TransmissionFormatType` and MUST NOT persist or require `CommunicationMethod`. Missing or legacy-only `CommunicationMethod` JSON SHALL result in `TransmissionFormatType0` without mapping old string values.

#### Scenario: Default format after upgrade from legacy JSON

- **WHEN** settings JSON contains only legacy `CommunicationMethod` (any value) and no `TransmissionFormatType`
- **THEN** deserialized `ScaleSettings.TransmissionFormatType` MUST be `TransmissionFormatType0`

#### Scenario: Explicit Type1 persists for Yaohua later phases

- **WHEN** settings JSON contains `"TransmissionFormatType": 1` (or equivalent enum name)
- **THEN** the value MUST deserialize as `TransmissionFormatType1` (runtime support is governed by protocol rules below)

### Requirement: Settings UI selects TransmissionFormatType

The settings UI SHALL present communication format as a selection control bound to `TransmissionFormatType`, displaying enum Descriptions `(tF0)` / `(tF1)`. The UI MUST NOT use a free-text field for `CommunicationMethod`. In this Phase, the UI MUST NOT enable `TransmissionFormatType1` for any `ScaleType` (including Yaohua).

#### Scenario: Non-Yaohua cannot select Type1

- **WHEN** user selects a non-Yaohua `ScaleType` (including TestMode)
- **THEN** `(tF1)` MUST be absent or disabled in the format selector

#### Scenario: Yaohua also cannot use Type1 in this Phase

- **WHEN** user selects `ScaleType.Yaohua` in this Phase
- **THEN** `(tF1)` MUST remain absent or disabled until a later change implements Yaohua tf1

### Requirement: Truck scale types are organized under Services/TruckScale

Truck-scale facade, router, and transmission protocols SHALL live under `MaterialClient.Common/Services/TruckScale/` with subfolders that classify responsibilities and device families (for example `Facade/`, `Routing/`, `Protocols/{Yaohua,DingSong,DingSongAddr4,PortableXpsy,TestMode,Unsupported}/`). These types MUST NOT remain flattened solely under `Services/Hardware/` alongside unrelated hardware services.

#### Scenario: Protocol types are not flat in Hardware

- **WHEN** a developer locates scale transmission protocol implementations after this change
- **THEN** those types MUST be under `Services/TruckScale/` (or its subfolders), not as sibling flat files only under `Services/Hardware/`

### Requirement: Protocol router resolves ScaleType times TransmissionFormatType

The system SHALL provide `ITruckScaleProtocolRouter` that resolves every in-enum pair `(ScaleType, TransmissionFormatType)` to an `IScaleTransmissionProtocol`. Callers of weighing flows SHALL continue to use `ITruckScaleWeightService` as the facade; the facade SHALL obtain the protocol via the router.

#### Scenario: Resolve Type0 for each ScaleType

- **WHEN** `Resolve` is called with any `ScaleType` and `TransmissionFormatType0`
- **THEN** the router MUST return the device-specific Type0 protocol implementation for that `ScaleType`

#### Scenario: Resolve Type1 yields unsupported protocol in this Phase

- **WHEN** `Resolve` is called with any `ScaleType` (including Yaohua) and `TransmissionFormatType1`
- **THEN** the router MUST return a shared unsupported/deferred protocol that does not parse real tf1 frames

### Requirement: Unsupported or deferred formats throw instead of fake success

An `IScaleTransmissionProtocol` that does not support the active `(ScaleType, TransmissionFormatType)` pair MUST throw on `EnsureSupported` / start / initialize paths. The system MUST NOT report online success with fabricated zero weights for unsupported or not-yet-implemented formats (including Yaohua Type1 in this Phase).

#### Scenario: Initialize fails for Type1

- **WHEN** `ITruckScaleWeightService.InitializeAsync` is invoked with `TransmissionFormatType1` for any `ScaleType`
- **THEN** initialization MUST fail by throwing (or propagating) an unsupported/not-implemented error that identifies ScaleType and TransmissionFormatType
- **AND** the service MUST NOT publish successful weight updates as if the format were supported

### Requirement: Type0 behavior is preserved per ScaleType

For `TransmissionFormatType0`, each existing `ScaleType` (Yaohua, DingSong, DingSongAddr4, PortableXPSY, TestMode) SHALL have an isolated protocol implementation that preserves the previous production continuous/simulated weight behavior for that type.

#### Scenario: Yaohua Type0 continuous path

- **WHEN** settings use `ScaleType.Yaohua` and `TransmissionFormatType0` and the serial stream matches existing continuous frames
- **THEN** `WeightUpdates` MUST emit parsed weights consistent with the pre-refactor Yaohua continuous path

#### Scenario: TestMode Type0 still simulates

- **WHEN** settings use `ScaleType.TestMode` and `TransmissionFormatType0`
- **THEN** the system MUST continue to provide simulated weight updates without requiring a real instrument tf1 path
