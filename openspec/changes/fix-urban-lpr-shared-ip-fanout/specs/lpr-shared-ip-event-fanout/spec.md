## ADDED Requirements

### Requirement: Shared-IP LPR recognition fans out one event per config row

When a physical LPR device recognition callback resolves a device IP, the system SHALL publish one `LicensePlateRecognizedEventData` for each valid `LicensePlateRecognitionConfig` row in current settings whose IP matches that device (after trim). Each event MUST carry the same plate, color/vehicle fields, timestamp, device type, and `LprImagePath` from that recognition, and MUST set `DeviceName` to that row’s `Name`. The system MUST keep a single SDK connection per IP (MUST NOT open a second handle solely because multiple rows share the IP).

#### Scenario: Scale and finished-product rows share one IP

- **WHEN** settings contain two valid LPR rows with the same IP, one `LprSiteType` scale and one finished product, with distinct names
- **AND** that IP produces one plate recognition callback
- **THEN** the system MUST publish exactly two `LicensePlateRecognizedEventData` events
- **AND** one event’s `DeviceName` MUST equal the scale row name
- **AND** the other event’s `DeviceName` MUST equal the finished-product row name
- **AND** both events MUST share the same plate number and `LprImagePath` value from that callback

#### Scenario: Single row for an IP

- **WHEN** settings contain exactly one valid LPR row for the recognized IP
- **AND** that IP produces one recognition callback
- **THEN** the system MUST publish exactly one event with that row’s `DeviceName`

#### Scenario: Duplicate names on the same IP collapse

- **WHEN** settings contain two valid rows with the same IP and the same `Name`
- **AND** that IP produces one recognition callback
- **THEN** the system MUST publish at most one event for that `Name`

### Requirement: Optional DeviceIp on recognition events

`LicensePlateRecognizedEventData` MAY include the recognized device IP string used for fan-out matching. Consumers that route by `DeviceName` and `LprSiteType` MUST continue to work when `DeviceIp` is absent (backward compatible).

#### Scenario: Fan-out events expose DeviceIp when available

- **WHEN** a recognition callback fans out events for a known IP
- **THEN** each published event SHOULD carry that IP in `DeviceIp` when the field exists
- **AND** `DeviceName` MUST still identify the config row for routing

### Requirement: Gate I/O must not open twice for one physical recognition fan-out

When multiple fan-out events for the same physical recognition would each enable gate I/O, `GateIoControlService` MUST open the gate at most once for that recognition. Within a short dedupe window (approximately two seconds) for the same plate, a second fan-out event MUST be skipped for gate open. When more than one fan-out row has `EnableGateIo` in the same recognition, the service MUST prefer the scale site-type row if it enables gate I/O; otherwise it MUST use the first enabling row and skip the rest.

#### Scenario: Scale and product both enable gate on shared IP

- **WHEN** two fan-out events arrive for the same plate within the dedupe window
- **AND** both matched configs have `EnableGateIo`
- **AND** one matched config is site type scale
- **THEN** the system MUST perform at most one gate-open sequence for that recognition
- **AND** MUST prefer the scale row’s gate settings when selecting which config drives the open

#### Scenario: Second fan-out within window skipped

- **WHEN** gate I/O already ran for plate P from a fan-out event
- **AND** another fan-out event for plate P arrives within the dedupe window
- **THEN** the service MUST NOT start a second gate-open for that event

### Requirement: SDK test injection does not fan out by IP

HTTP or test APIs that publish `LicensePlateRecognizedEventData` for an explicitly chosen `DeviceName` MUST publish exactly that one event and MUST NOT fan out to other rows that share the same IP.

#### Scenario: Test passage publish targets one device name

- **WHEN** an operator or test client requests LPR test injection with a specific device name
- **THEN** the system MUST publish one event with that `DeviceName`
- **AND** MUST NOT publish additional events for other configs that share the device IP
