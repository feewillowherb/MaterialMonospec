## 1. Branch

- [ ] 1.1 From MaterialClient trunk, create branch `add-urban-stable-upload-cache` before the first product edit. Do not start that edit without an explicit Human `APPROVED` for this change.

## 2. Configuration and settings

- [ ] 2.1 Add `WeighingConfiguration.EnableUploadOnStable` with default `false`, persisted by the existing weighing JSON. A missing field MUST deserialize as `false`. Do not add the 900-second value as a setting.
- [ ] 2.2 On the Urban host settings window, add a 「稳定后上传」 toggle in the weighing section, visible only for that host, and persist it with the other weighing settings. Do not inject a repository into the view model.
- [ ] 2.3 Reload `EnableUploadOnStable` together with `EnableLatestPlateNumber`, `EnablePlateRewrite`, and `EnableMatchOnStable` when `SettingsSavedEventData` arrives.

## 3. Stable upload and produced-plate hold

- [ ] 3.1 Add in-memory `ProducedPlateHold` (`PlateNumber`, `CreatedAtUtc`, `WeighingRecordId`) on the existing attended-weighing cycle state. Do not register a new DI service and do not use a tuple for the hold.
- [ ] 3.2 When the flag is on and the Urban weighing path creates a record on `WeightStabilized`, store the hold from that record's saved `PlateNumber` before later LPR can change the recommendation, then call `EnsureReadyForUploadAsync` once.
- [ ] 3.3 While a hold is younger than 900 seconds, refuse a new create whose snapshot plate is the same string, including empty. A different plate MUST NOT be treated as a hit. While the open record id remains and weight stays above `MinWeightThreshold`, keep forcing `WaitingForDeparture`.
- [ ] 3.4 On the existing off-scale edges (`weight < MinWeightThreshold` from `WaitingForStability`, `WeightStabilized`, or `WaitingForDeparture`), remove every hold. Do not delete weighing records or uploaded data. Leave equal-to-threshold on the scale, and leave the existing plate rewrite plus selection-cache clear in place.
- [ ] 3.5 At 900 seconds from `CreatedAtUtc` without off-scale, clear every hold, clear the open record id, and set `WaitingForStability`. Do not call `RewriteAndResetCycleAsync` for this edge. The next stable sample MAY create one record and then hold it; it MUST NOT create a record on every later sample.
- [ ] 3.6 When the flag is off, or the host is not the Urban weighing path, do not write holds, do not promote on stable, and do not run the 900-second release.

## 4. Tests

- [ ] 4.1 Extend `AttendedWeighingServiceTests` for: flag off keeps off-scale promotion; flag on promotes on the first stable create; the same snapshot plate does not create a second record; a different plate is not a hold hit; off-scale clears holds and still keeps the record; weight equal to `MinWeightThreshold` keeps the hold.
- [ ] 4.2 Cover the 900-second fallback: status returns to `WaitingForStability`, one later stable create is allowed, and a following sample does not create another record while the new record is open.
- [ ] 4.3 Extend the Urban extension tests so an already `Pending` or `Synced` row does not change `SyncStatus` when off-scale rewrites the plate and anomaly state is unchanged.
