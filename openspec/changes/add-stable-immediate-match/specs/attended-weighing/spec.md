## ADDED Requirements

### Requirement: Trigger early match after weight stabilized when configured

AttendedWeighingService / WeighingRecordService SHALL，在 `EnableMatchOnStable` 为 true 且本周期称重记录已在 `WeightStabilized` 创建成功后，在推荐车牌非空时尝试发布 `TryMatchEvent`（须遵守 `ShouldSkipWaybillMatching()`）。下磅进入 `OffScale` 时 SHALL 仍执行车牌重写与周期重置；当 `EnableMatchOnStable` 为 true 时，仅在该记录 `MatchedId` 仍为空时发布兜底 `TryMatchEvent`，若 `MatchedId` 非空则 MUST NOT 再发布。

#### Scenario: Early match after create on stable

- **GIVEN** EnableMatchOnStable=true and waybill matching is not skipped
- **WHEN** OnWeightStabilizedAsync successfully creates a weighing record with a non-empty plate
- **THEN** SHALL publish TryMatchEvent for that record ID before the vehicle reaches OffScale

#### Scenario: Skip OffScale TryMatch when already matched on stable

- **GIVEN** EnableMatchOnStable=true
- **AND** the cycle weighing record has MatchedId set (matched during/after stable TryMatch)
- **WHEN** status transitions to OffScale and RewriteAndResetCycleAsync / TryReWritePlateNumberAsync runs
- **THEN** SHALL still execute plate rewrite and cycle reset
- **AND** SHALL NOT publish TryMatchEvent for that record

#### Scenario: OffScale fallback TryMatch when not matched on stable

- **GIVEN** EnableMatchOnStable=true and waybill matching is not skipped
- **AND** the cycle weighing record still has MatchedId null at OffScale
- **WHEN** TryReWritePlateNumberAsync runs on OffScale
- **THEN** SHALL publish TryMatchEvent as fallback

## MODIFIED Requirements

### Requirement: Subscribe to ILocalEventBus external events on StartAsync

AttendedWeighingOrchestrator SHALL subscribe to:
- LicensePlateRecognizedEventData → delegate to PlateNumberService
- GhostGateSessionResetEventData → remove abandoned plate and publish updated plate
- SettingsSavedEventData → refresh runtime configuration (EnableLatestPlateNumber, EnablePlateRewrite, EnableMatchOnStable)

#### Scenario: License plate event triggers plate cache update
- **WHEN** LicensePlateRecognizedEventData with plate "京A12345" is received
- **THEN** SHALL call PlateNumberService recognition method and publish PlateNumberChangedEventData

#### Scenario: Ghost gate session reset
- **WHEN** GhostGateSessionResetEventData with AbandonedPlateNumber="京A12345" is received
- **THEN** SHALL remove the plate from cache and publish PlateNumberChangedEventData with updated most frequent plate

#### Scenario: Settings saved refreshes runtime config
- **WHEN** SettingsSavedEventData is received
- **THEN** SHALL reload EnableLatestPlateNumber, EnablePlateRewrite, and EnableMatchOnStable from settings
