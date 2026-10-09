## MODIFIED Requirements

### Requirement: Trigger Vzvision LPR capture at specified phases

WeighingCaptureService SHALL trigger LPR capture (`TriggerCaptureAsync` via `ILprDevice`) for configured LPR devices **only** at the WeightStabilized flow phase (after weighing record creation), when:
- SystemSettings.EnableTriggerLprCapture is true
- Each row’s `DeviceType` resolves via `ILprDeviceResolver` to a device that supports active capture (skip and log rows that do not)

When multiple valid LPR rows share the same IP, the service MUST call `TriggerCaptureAsync` **at most once per distinct IP** in that trigger pass (physical device dedupe). Recognition callbacks for that IP MUST still fan out per config row as defined by `lpr-shared-ip-event-fanout`.

The service MUST NOT trigger active LPR capture on WaitingForStability or OffScale transitions. The service MUST NOT use `SystemSettings.LprDeviceType` as the vendor for every row.

#### Scenario: WeightStabilized trigger enabled

- **WHEN** EnableTriggerLprCapture=true and LPR devices are configured
- **AND** the weighing flow enters WeightStabilized capture (`CaptureOnWeightStabilized`)
- **THEN** SHALL call TriggerCaptureAsync for each valid LPR device whose `DeviceType` supports active capture (after optional delay), subject to distinct-IP dedupe

#### Scenario: Shared IP rows trigger once

- **WHEN** EnableTriggerLprCapture=true
- **AND** two valid LPR rows share the same IP and both support active capture
- **AND** the weighing flow enters WeightStabilized capture
- **THEN** SHALL call TriggerCaptureAsync at most once for that IP
- **AND** MUST NOT invoke TriggerCaptureAsync twice solely because two rows share the IP

#### Scenario: WaitingForStability does not trigger LPR

- **WHEN** status transitions from OffScale to WaitingForStability
- **THEN** SHALL NOT call LPR `TriggerCaptureAsync` for that transition

#### Scenario: OffScale does not trigger LPR

- **WHEN** status transitions to OffScale (normal or abnormal departure)
- **THEN** SHALL NOT call LPR `TriggerCaptureAsync` for that transition

#### Scenario: LPR trigger disabled

- **WHEN** EnableTriggerLprCapture=false
- **THEN** SHALL skip LPR trigger and log info

#### Scenario: Mixed types skip unsupported capture

- **WHEN** one LPR row is Hikvision (supports active capture) and one is a type that does not
- **THEN** SHALL trigger capture only on supporting rows
- **AND** SHALL NOT skip Hikvision solely because a global setting is another vendor
