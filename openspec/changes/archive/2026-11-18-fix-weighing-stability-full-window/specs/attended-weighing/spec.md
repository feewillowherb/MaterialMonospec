## MODIFIED Requirements

### Requirement: Construct stability stream with valid-data filtering

WeighingStreamPipeline SHALL create a stability stream (IObservable<WeightStabilityInfo>) that:
1. First downsamples the shared weight source by buffering over StabilityCheckIntervalMs and taking the last value of each non-empty buffer (one sample per check interval)
2. Then maintains a sliding window of exactly `periods` downsampled samples, where `periods = max(1, floor(StabilityWindowMs / StabilityCheckIntervalMs))`
3. Treats the window as ready for stability evaluation only when it contains exactly `periods` samples
4. Requires every sample in the ready window to be above MinWeightThreshold (no below-threshold samples allowed in a stable window)
5. Determines stability when the ready window's range (max-min) <= WeightStabilityThreshold * 2
6. When stable, StableWeight SHALL be (min+max)/2; otherwise StableWeight SHALL be null and IsStable SHALL be false
7. Emits DistinctUntilChanged on IsStable property

AttendedWeighingService's inline stability stream used for record StableWeight SHALL apply the same rules as CreateStabilityStream.

#### Scenario: Full window of valid stable samples
- **WHEN** StabilityWindowMs is 3000 and StabilityCheckIntervalMs is 200 (periods=15)
- **AND** 15 consecutive downsampled samples all exceed MinWeightThreshold
- **AND** range (max-min) <= WeightStabilityThreshold * 2
- **THEN** IsStable SHALL be true, StableWeight SHALL be (min+max)/2

#### Scenario: Premature plateau shorter than full window
- **WHEN** StabilityWindowMs is 3000 and StabilityCheckIntervalMs is 200 (periods=15)
- **AND** fewer than 15 consecutive downsampled samples above MinWeightThreshold have been collected since the weight rose above threshold
- **THEN** IsStable SHALL be false regardless of how small the range is among the available samples

#### Scenario: Window contains a below-threshold sample
- **WHEN** a ready window of `periods` downsampled samples includes at least one value <= MinWeightThreshold
- **THEN** IsStable SHALL be false, StableWeight SHALL be null

#### Scenario: Full window but range exceeds threshold
- **WHEN** a ready window of `periods` samples are all above MinWeightThreshold
- **AND** range (max-min) > WeightStabilityThreshold * 2
- **THEN** IsStable SHALL be false, StableWeight SHALL be null

#### Scenario: No valid data points above threshold
- **WHEN** all downsampled points in the current partial or ready window are below MinWeightThreshold
- **THEN** IsStable SHALL be false, StableWeight SHALL be null

#### Scenario: Mid-ascent short plateau must not lock
- **WHEN** weight crosses MinWeightThreshold and briefly plateaus near 0.55t for less than StabilityWindowMs with small range
- **THEN** IsStable SHALL remain false until a full periods window of above-threshold samples has elapsed
