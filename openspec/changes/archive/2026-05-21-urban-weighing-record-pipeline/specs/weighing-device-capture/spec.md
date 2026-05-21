## ADDED Requirements

### Requirement: UrbanMode reuses existing ITruckScaleWeightService

UrbanMode (201) SHALL use the same `ITruckScaleWeightService.WeightUpdates` observable as the attended weighing mode, without requiring new device interfaces.

#### Scenario: UrbanMode subscribes to weight updates
- **WHEN** UrbanWeighingService starts
- **THEN** SHALL subscribe to ITruckScaleWeightService.WeightUpdates
- **AND** SHALL NOT create a separate device connection
- **AND** SHALL share the same serial port connection as other modes

#### Scenario: UrbanMode uses shared pipeline
- **WHEN** weight data flows through IWeighingStreamPipeline
- **THEN** UrbanWeighingService SHALL receive the same stability and status streams as AttendedWeighing
- **AND** SHALL NOT require separate pipeline configuration
