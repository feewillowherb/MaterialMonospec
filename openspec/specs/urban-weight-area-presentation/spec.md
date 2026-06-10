# urban-weight-area-presentation Specification

## Purpose
TBD - created by archiving change align-urban-weight-area-with-attended. Update Purpose after archive.
## Requirements
### Requirement: Urban weight area layout alignment with Attended

The Urban attended weighing window `WeightAreaContent` SHALL use the same three-column content structure and margins as `AttendedWeighingWindow` weight area: left plate display, center weight card, right status and loading indicator. The Urban weight area background MAY differ from Attended (e.g. gradient vs banner image); this requirement applies only to the foreground content layer.

#### Scenario: Content layer margins
- **WHEN** the Urban weight area is rendered
- **THEN** the foreground content `Grid` MUST use `Margin="24,32"`
- **AND** MUST use `HorizontalAlignment="Stretch"` and `VerticalAlignment="Stretch"`
- **AND** MUST NOT use only `Margin="24,0"` with vertically centered compact layout as the sole layout model

#### Scenario: No DeliveryType controls in Urban weight area
- **WHEN** the Urban weight area center column is rendered
- **THEN** it MUST NOT include 收/发料 DeliveryType selectors, `AnimatedDeliveryTypeRadioButton`, or DeliveryType change notification overlays
- **AND** it MUST still present current weight and unit in the Attended visual style (rounded `#5A7FE6` card)

### Requirement: Urban live plate display in weight area

The Urban weight area left column SHALL display the current LPR session plate using the same presentation as Attended (`MostFrequentPlateNumber`), not a decorative placeholder block.

#### Scenario: Plate card presentation
- **WHEN** the Urban weight area left column is shown
- **THEN** it MUST bind to `MostFrequentPlateNumber` with `TargetNullValue='--'`
- **AND** MUST use the Attended-equivalent card styling (`#5A7FE6` background, corner radius 8, padding, horizontal offset transform)

#### Scenario: Plate updates from LPR pipeline
- **WHEN** `PlateNumberChangedMessage` is published on the message bus
- **THEN** `UrbanAttendedWeighingViewModel` MUST update `MostFrequentPlateNumber` on the UI thread
- **AND** the weight area MUST reflect the new value without requiring a list reload

#### Scenario: Initial plate on initialize
- **WHEN** `UrbanAttendedWeighingViewModel.Initialize()` runs and `IAttendedWeighingService` is available
- **THEN** `MostFrequentPlateNumber` MUST be set from `GetMostFrequentPlateNumber()`

### Requirement: Urban weight value presentation matches Attended

The Urban weight area center column SHALL display `CurrentWeight` with the same formatting and typography as Attended (excluding DeliveryType-adjacent layout only).

#### Scenario: Weight formatting and size
- **WHEN** the center weight value is displayed
- **THEN** it MUST bind to `CurrentWeight` with `StringFormat='{}{0:F2}'`
- **AND** MUST use white foreground, `FontSize="64"`, and bold weight
- **AND** the unit「吨」MUST use `FontSize="24"` with a vertical separator line (1px, white, opacity 0.3) before the unit text, matching Attended

### Requirement: Urban weight area status column matches Attended

The Urban weight area right column SHALL use Attended status semantics: white status text and loading dots while weighing is active. It MUST NOT use `WeightStatus` with `WeightStatusColor` in the weight area.

#### Scenario: Status text binding
- **WHEN** the right column status is displayed
- **THEN** it MUST bind to `CurrentWeighingStatusText`
- **AND** MUST use `Foreground="White"`, `FontSize="18"`, `FontWeight="Bold"`
- **AND** MUST use the same horizontal alignment and negative margin convention as Attended (`Margin="-150,0,0,0"` or equivalent documented offset)

#### Scenario: Loading animation while weighing
- **WHEN** `IsWeighingActive` is true
- **THEN** `LoadingDotsAnimation` MUST be visible/active in the right column with Attended-equivalent placement (`Margin="-75,0,0,0"` or equivalent)
- **AND** when `IsWeighingActive` is false, the animation MUST not indicate an active weighing session

#### Scenario: Status derived from attended weighing status
- **WHEN** `StatusChangedEventData` is received
- **THEN** the ViewModel MUST update internal attended weighing status and raise changes for `CurrentWeighingStatusText` and `IsWeighingActive`
- **AND** status text MUST use the same status-to-string mapping as Attended for `AttendedWeighingStatus` values

### Requirement: Shared loading dots control for Urban and Attended

`LoadingDotsAnimation` SHALL be consumable from `MaterialClient.Urban` without project reference to the main `MaterialClient` desktop assembly.

#### Scenario: Control location
- **WHEN** Urban references the loading animation control
- **THEN** the control MUST reside in `MaterialClient.UI` (or a namespace exported by that assembly)
- **AND** `AttendedWeighingWindow` MUST be updated to reference the new location without behavior change

