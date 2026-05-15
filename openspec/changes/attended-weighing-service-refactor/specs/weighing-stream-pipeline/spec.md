## ADDED Requirements

### Requirement: Construct weight stream from raw scale data
WeighingStreamPipeline SHALL create a buffered weight stream (IObservable<decimal>) from ITruckScaleWeightService.WeightUpdates, using Buffer(StabilityCheckIntervalMs) and taking the last value from each buffer.

#### Scenario: Weight stream buffers correctly
- **WHEN** raw weight updates arrive at intervals shorter than StabilityCheckIntervalMs
- **THEN** SHALL emit one value per interval window (the last value in the buffer)

### Requirement: Construct stability stream with valid-data filtering
WeighingStreamPipeline SHALL create a stability stream (IObservable<WeightStabilityInfo>) that:
1. Buffers weight data over StabilityWindowMs with StabilityCheckIntervalMs sliding interval
2. Filters data points above MinWeightThreshold for stability calculation
3. Requires minimum data points (max(8, windowMs/intervalMs * 0.5))
4. Determines stability when range (max-min of valid points) <= WeightStabilityThreshold * 2 AND has enough valid data points
5. Emits DistinctUntilChanged on IsStable property

#### Scenario: Sufficient valid stable data
- **WHEN** 20 data points arrive within StabilityWindowMs, all above MinWeightThreshold, with range <= threshold*2
- **THEN** IsStable SHALL be true, StableWeight SHALL be (min+max)/2

#### Scenario: Insufficient valid data points
- **WHEN** only 3 valid data points arrive within StabilityWindowMs
- **THEN** IsStable SHALL be false regardless of range

#### Scenario: No valid data points above threshold
- **WHEN** all data points in the window are below MinWeightThreshold
- **THEN** IsStable SHALL be false, StableWeight SHALL be null

### Requirement: Construct combined status stream
WeighingStreamPipeline SHALL create a status stream by combining weightStream, stabilityStream, recordIdStream, and current status using CombineLatest, applying state transition rules, and emitting DistinctUntilChanged on status.

#### Scenario: Status transition triggered by weight threshold
- **WHEN** status is OffScale and weight transitions above MinWeightThreshold
- **THEN** combined stream SHALL emit WaitingForStability

#### Scenario: Status transition triggered by stability
- **WHEN** status is WaitingForStability and stability.IsStable becomes true and no record exists
- **THEN** combined stream SHALL emit WeightStabilized

### Requirement: Share source stream to avoid multiple subscriptions
WeighingStreamPipeline SHALL use Publish().RefCount() on the raw weight source to ensure only one subscription to ITruckScaleWeightService.WeightUpdates regardless of how many derived streams exist.

#### Scenario: Multiple derived streams from single source
- **WHEN** weightStream and stabilityStream are both active
- **THEN** ITruckScaleWeightService.WeightUpdates SHALL have exactly one subscriber

### Requirement: StartWith initial values
WeighingStreamPipeline SHALL ensure weight stream starts with 0m and stability stream starts with IsStable=false, to provide immediate initial state to subscribers.

#### Scenario: Immediate initial emission
- **WHEN** pipeline is constructed and subscribed
- **THEN** weight stream SHALL emit 0m and stability stream SHALL emit IsStable=false without waiting for data

### Requirement: Replay latest stability value
WeighingStreamPipeline SHALL apply Replay(1).RefCount() to the stability stream so new subscribers immediately receive the latest stability state.

#### Scenario: Late subscriber gets latest stability
- **WHEN** a new subscriber attaches to the stability stream after it has already emitted values
- **THEN** SHALL immediately receive the most recent WeightStabilityInfo
