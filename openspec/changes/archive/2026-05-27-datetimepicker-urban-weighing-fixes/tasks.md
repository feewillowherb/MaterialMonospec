## 1. License Plate Validation

- [x] 1.1 Add `PlateNumberValidator` using statement to `UrbanAttendedWeighingViewModel.cs` (namespace: `MaterialClient.Common.Providers`)
- [x] 1.2 Modify `ApproveRecordAsync` method to validate `result.PlateNumber` using `PlateNumberValidator.IsValidChinesePlateNumber` before calling `UpdateWeighingRecordAsync`
- [x] 1.3 Add error handling for invalid license plates: show error dialog and return early without calling service
- [x] 1.4 Add null/empty check for `PlateNumber` and display appropriate error message

## 2. Anomaly Flag Update

- [x] 2.1 Add `IUrbanAnomalyDetector` dependency injection to `WeighingRecordService` constructor (if not already present)
- [x] 2.2 Modify `UpdateWeighingRecordAsync` method in `WeighingRecordService.cs` to fetch the updated `WeighingRecord` entity after persisting changes
- [x] 2.3 Add check for existing `UrbanWeighingExtension` using `GetByWeighingRecordIdAsync` (skip if null)
- [x] 2.4 Call `UrbanAnomalyDetector.IsAnomaly` with the updated record and anomaly detection config
- [x] 2.5 Call `UpdateAnomalyFlagAsync` with extension ID and calculated anomaly status

## 3. DateTimePicker UI Controls

- [x] 3.1 Add Ursa namespace declaration to `UrbanAttendedWeighingWindow.axaml`: `xmlns:u="https://irihi.tech/ursa"`
- [x] 3.2 Replace first filter TextBox with `<u:DateTimePicker>` for start time, set `Width="130"`, `DisplayFormat="MM-dd HH:mm"`, `PanelFormat="yyyy-MM-dd HH:mm"`
- [x] 3.3 Replace second filter TextBox with `<u:DateTimePicker>` for end time with same properties
- [x] 3.4 Bind start DateTimePicker `SelectedDate` to `{Binding StartTime}`
- [x] 3.5 Bind end DateTimePicker `SelectedDate` to `{Binding EndTime}`

## 4. ViewModel Property Binding

- [x] 4.1 Verify `StartTime` and `EndTime` properties exist in `UrbanAttendedWeighingViewModel` (nullable `DateTime?`)
- [x] 4.2 Ensure properties are decorated with `[Reactive]` attribute for reactive binding
- [x] 4.3 Verify `SearchAsync` and `ResetSearchAsync` commands use these properties for filtering

## 5. Testing

- [ ] 5.1 Test approval with valid license plate (e.g., "京A12345"): should succeed and update record
- [ ] 5.2 Test approval with invalid license plate (e.g., "ABC123"): should show error and block save
- [ ] 5.3 Test approval with null/empty license plate: should show error and block save
- [ ] 5.4 Test anomaly flag update: approve a record and verify `IsAnomaly` value changes in database
- [ ] 5.5 Test DateTimePicker: select date-time range and verify list filters correctly
- [ ] 5.6 Test reset button: verify DateTimePicker controls clear and list shows all records
- [ ] 5.7 Run existing unit tests to ensure no regressions in Material module

## 6. Documentation

- [x] 6.1 Update XML documentation comments for `ApproveRecordAsync` to describe validation behavior
- [x] 6.2 Update XML documentation comments for `UpdateWeighingRecordAsync` to describe anomaly flag update
- [x] 6.3 Add inline comments explaining anomaly detection integration in `WeighingRecordService.cs`
