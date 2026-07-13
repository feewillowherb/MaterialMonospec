# Tasks — Default DeliveryType Setting

Implementation tasks for change `add-delivery-type-default-setting`. All code follows `repos/MaterialClient/AGENTS.md`: .NET 10, file-scoped namespaces, `[Reactive]` ReactiveUI binding, ABP DI conventions, single-source-of-truth for display labels, English-only identifiers.

## 1. Persisted setting (MaterialClient.Common)

- [x] 1.1 Add `DefaultDeliveryType` property to `src/MaterialClient.Common/Configuration/SystemSettings.cs`
  - Type `DeliveryType` (import `MaterialClient.Common.Entities.Enums`), default `DeliveryType.Receiving`, with XML doc comment (mirror `DefaultWeighingMode`).
- [x] 1.2 Add `Task<DeliveryType> GetDefaultDeliveryTypeAsync()` to `ISettingsService` interface and `SettingsService` impl in `src/MaterialClient.Common/Services/SettingsService.cs`
  - Return `(await GetSettingsAsync()).SystemSettings.DefaultDeliveryType`; mirror `GetWeighingModeAsync()`.
- [x] 1.3 Verify no EF Core migration is needed — `SystemSettings` is JSON-serialized into the existing `SystemSettingsJson` column (confirm by building; do NOT generate a migration).

## 2. Settings UI (MaterialClient.UI)

- [x] 2.1 Add a reactive property to `src/MaterialClient.UI/ViewModels/SettingsWindowViewModel.cs`
  - `[Reactive] private DeliveryType _defaultDeliveryType = DeliveryType.Receiving;`
- [x] 2.2 Add a single-source options source for the 收料/发料 labels used by the new control (one `ObservableCollection` or static option list; no duplicated literals).
- [x] 2.3 Wire load in `LoadSettingsAsync`: `DefaultDeliveryType = settings.SystemSettings.DefaultDeliveryType;`
- [x] 2.4 Wire save in `SaveAsync`: after preserving `systemSettings`, set `systemSettings.DefaultDeliveryType = DefaultDeliveryType;` alongside the sibling assignments.
- [x] 2.5 Add a `ComboBox` (or equivalent selection control) bound to `DefaultDeliveryType` with the 收料/发料 options into the 系统设置 pane of `src/MaterialClient.UI/Views/SettingsWindow.axaml`.

## 3. Startup apply (MaterialClient.AttendedWeighing)

- [x] 3.1 In `AttendedWeighingViewModel.InitializeOnFirstLoadAsync()` (`src/MaterialClient.AttendedWeighing/ViewModels/AttendedWeighingViewModel.cs`), read the default and apply it
  - `var dt = await _settingsService.GetDefaultDeliveryTypeAsync();`
  - Guard: if `!Enum.IsDefined(dt)` fall back to `DeliveryType.Receiving`.
  - Call `_attendedWeighingService?.SetDeliveryType(dt);` (reuse existing event path; no new event type).
- [x] 3.2 Confirm the existing `DeliveryTypeChangedEventData` subscription correctly updates `IsReceiving` when the saved value differs from the `Receiving` seed (no new subscription code expected).

## 4. Tests

- [x] 4.1 Unit test: `SystemSettings.DefaultDeliveryType` survives `JsonSerializer` serialize/deserialize round-trip for both `Receiving` and `Sending`, and defaults to `Receiving` when JSON omits the field.
- [x] 4.2 Unit test: `SettingsService.GetDefaultDeliveryTypeAsync` returns the persisted value; returns `Receiving` on an empty settings store.
- [x] 4.3 Unit test: `SettingsWindowViewModel` Load populates `DefaultDeliveryType` from settings and Save writes it back (mocked `ISettingsService`).
- [x] 4.4 Unit test: `AttendedWeighingViewModel.InitializeOnFirstLoadAsync` calls `SetDeliveryType` with the saved default; with saved `Sending` the manager's current becomes `Sending`, and with saved `Receiving` no `DeliveryTypeChangedEventData` is published.
- [x] 4.5 Unit test: invalid/unknown stored value is guarded to `Receiving` (no throw).

## 5. Build & manual verification

- [x] 5.1 Build the solution using the fixed verify output directory per AGENTS.md: `dotnet build MaterialClient.sln -o .build-verify` (run in `repos/MaterialClient`).
- [ ] 5.2 Manual: set default to 发料 in 系统设置, save, restart the app, confirm the boot mode shows 发料; set back to 收料, restart, confirm 收料.
- [ ] 5.3 Manual: confirm toggling 收料/发料 at runtime still works during a session and does not overwrite the persisted default.
- [ ] 5.4 Manual: confirm the Urban client boot is unaffected by the setting.
