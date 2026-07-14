## MODIFIED Requirements

### Requirement: Trigger Vzvision LPR capture at specified phases

WeighingCaptureService SHALL trigger LPR capture (`TriggerCaptureAsync` via `ILprDevice`) for all configured LPR devices **only** at the WeightStabilized flow phase (after weighing record creation), when:
- SystemSettings.EnableTriggerLprCapture is true
- The configured `LprDeviceType` resolves to a device that supports active capture

The service MUST NOT trigger active LPR capture on WaitingForStability or OffScale transitions.

#### Scenario: WeightStabilized trigger enabled

- **WHEN** EnableTriggerLprCapture=true and LPR devices are configured
- **AND** the weighing flow enters WeightStabilized capture (`CaptureOnWeightStabilized`)
- **THEN** SHALL call TriggerCaptureAsync for each valid LPR device (after optional delay)

#### Scenario: WaitingForStability does not trigger LPR

- **WHEN** status transitions from OffScale to WaitingForStability
- **THEN** SHALL NOT call LPR `TriggerCaptureAsync` for that transition

#### Scenario: OffScale does not trigger LPR

- **WHEN** status transitions to OffScale (normal or abnormal departure)
- **THEN** SHALL NOT call LPR `TriggerCaptureAsync` for that transition

#### Scenario: LPR trigger disabled

- **WHEN** EnableTriggerLprCapture=false
- **THEN** SHALL skip LPR trigger and log info
