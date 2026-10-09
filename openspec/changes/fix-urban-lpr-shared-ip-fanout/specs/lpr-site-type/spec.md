## MODIFIED Requirements

### Requirement: Urban recognition branches on LPR site type

When the Urban product handles a plate recognition event, post-recognition persistence MUST read the matched `LicensePlateRecognitionConfig` site type for that event’s `DeviceName`. Checkpoint and finished-product MUST create an `UrbanPassageRecord` (see `urban-passage-record`). Scale MUST keep the existing weighing path and MUST NOT write a passage record for that event. When multiple events are fan-out from one physical recognition that shares an IP across rows (see `lpr-shared-ip-event-fanout`), each event MUST be routed independently by its own row’s site type, so scale weighing and checkpoint/finished-product passage MAY both run for the same plate capture. DeviceManager start/stop, SDK capture, and gate I/O MAY still treat all configured LPR devices as startable devices; they MUST NOT skip starting a device because it is checkpoint or finished product. Gate open frequency for shared-IP fan-out is constrained by `lpr-shared-ip-event-fanout`, not by skipping device start.

#### Scenario: Recognition path uses site type for persistence

- **WHEN** a plate is recognized from a configured Urban LPR device
- **THEN** the persistence action MUST follow that row’s site type (weighing vs passage)
- **AND** MUST NOT ignore checkpoint or finished-product site type for create-record routing

#### Scenario: Shared IP scale and finished-product both persist

- **WHEN** settings contain scale and finished-product LPR rows with the same IP and distinct names
- **AND** one physical recognition on that IP fans out one event per row
- **THEN** the scale event MUST follow the weighing path and MUST NOT insert a passage record
- **AND** the finished-product event MUST insert a passage record with finished-product source and MUST NOT create a weighing record for that passage event
